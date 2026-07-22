import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../diary/diary_overview.dart';

const backupFormatVersion = 5;
const _backupKeyFileNames = {'shadow-diary-backup-key.json', 'backup-key.json'};

final backupImportServiceProvider = Provider<BackupImportService>((ref) {
  return const UnavailableBackupImportService();
});

enum BackupImportMode { overwrite, incremental }

enum BackupImportErrorCode {
  unavailable,
  invalidBackup,
  unsupportedBackupFormat,
  missingKeyFile,
  unreadableFile,
  transferInProgress,
  importFailed,
}

class BackupImportException implements Exception {
  const BackupImportException(this.code, [this.cause]);

  final BackupImportErrorCode code;
  final Object? cause;

  @override
  String toString() => 'BackupImportException($code, $cause)';
}

class BackupImportPreview {
  const BackupImportPreview({
    required this.sessionId,
    required this.fileName,
    required this.appName,
    required this.appVersion,
    required this.exportedAt,
    required this.formatVersion,
    required this.diaryCount,
    required this.archiveCount,
    required this.attachmentCount,
    required this.mediaFileCount,
    required this.conflictDiaryCount,
  });

  final String sessionId;
  final String fileName;
  final String appName;
  final String appVersion;
  final DateTime exportedAt;
  final int formatVersion;
  final int diaryCount;
  final int archiveCount;
  final int attachmentCount;
  final int mediaFileCount;
  final int conflictDiaryCount;
}

class BackupImportResult {
  const BackupImportResult({
    required this.importedDiaryCount,
    required this.importedArchiveCount,
    required this.skippedDiaryCount,
  });

  final int importedDiaryCount;
  final int importedArchiveCount;
  final int skippedDiaryCount;
}

abstract interface class BackupImportService {
  Future<BackupImportPreview?> selectBackup();

  Future<BackupImportResult> importBackup(
    BackupImportPreview preview,
    BackupImportMode mode,
  );

  Future<void> discardPreview(BackupImportPreview preview);
}

class UnavailableBackupImportService implements BackupImportService {
  const UnavailableBackupImportService();

  @override
  Future<BackupImportPreview?> selectBackup() {
    throw const BackupImportException(BackupImportErrorCode.unavailable);
  }

  @override
  Future<BackupImportResult> importBackup(
    BackupImportPreview preview,
    BackupImportMode mode,
  ) {
    throw const BackupImportException(BackupImportErrorCode.unavailable);
  }

  @override
  Future<void> discardPreview(BackupImportPreview preview) async {}
}

class PickedBackupFile {
  const PickedBackupFile({required this.path, required this.name});

  final String path;
  final String name;
}

typedef PickBackupFile = Future<PickedBackupFile?> Function();
typedef LoadBackupDirectory = Future<Directory> Function();

class DeviceBackupImportService implements BackupImportService {
  DeviceBackupImportService(
    this._database, {
    PickBackupFile? pickBackupFile,
    LoadBackupDirectory? loadTemporaryDirectory,
    LoadBackupDirectory? loadDocumentsDirectory,
    Uuid? uuid,
  }) : _pickBackupFile = pickBackupFile ?? _pickFile,
       _loadTemporaryDirectory =
           loadTemporaryDirectory ?? getTemporaryDirectory,
       _loadDocumentsDirectory =
           loadDocumentsDirectory ?? getApplicationDocumentsDirectory,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final PickBackupFile _pickBackupFile;
  final LoadBackupDirectory _loadTemporaryDirectory;
  final LoadBackupDirectory _loadDocumentsDirectory;
  final Uuid _uuid;
  final Map<String, _BackupSession> _sessions = {};

  bool _isBusy = false;

  @override
  Future<BackupImportPreview?> selectBackup() {
    return _exclusive(() async {
      final pickedFile = await _pickBackupFile();
      if (pickedFile == null) return null;
      final sourceFile = File(pickedFile.path);
      if (!await sourceFile.exists()) {
        throw const BackupImportException(BackupImportErrorCode.unreadableFile);
      }

      await _discardAllSessions();
      final temporaryDirectory = await _loadTemporaryDirectory();
      final importRoot = Directory(
        p.join(temporaryDirectory.path, 'shadow_diary_import'),
      );
      await importRoot.create(recursive: true);
      final sessionId = _uuid.v4();
      final sessionDirectory = Directory(p.join(importRoot.path, sessionId));
      await sessionDirectory.create(recursive: true);

      try {
        final inspected = _extractAndInspect(
          sourcePath: sourceFile.path,
          sessionDirectory: sessionDirectory,
        );
        final localDates = await _loadLocalDiaryDates();
        final conflictCount = inspected.diaryCreatedAt
            .where((timestamp) => localDates.contains(_dateKey(timestamp)))
            .length;
        final session = _BackupSession(
          id: sessionId,
          sourcePath: sourceFile.path,
          directory: sessionDirectory,
          rootPrefix: inspected.rootPrefix,
          databasePath: inspected.databasePath,
          keyHex: inspected.keyHex,
        );
        _sessions[sessionId] = session;
        return BackupImportPreview(
          sessionId: sessionId,
          fileName: pickedFile.name,
          appName: inspected.metadata.appName,
          appVersion: inspected.metadata.appVersion,
          exportedAt: inspected.metadata.exportedAt,
          formatVersion: inspected.metadata.formatVersion,
          diaryCount: inspected.diaryCreatedAt.length,
          archiveCount: inspected.archiveCount,
          attachmentCount: inspected.attachmentCount,
          mediaFileCount: inspected.mediaFileCount,
          conflictDiaryCount: conflictCount,
        );
      } on BackupImportException {
        await _deleteDirectory(sessionDirectory);
        rethrow;
      } on Object catch (error) {
        await _deleteDirectory(sessionDirectory);
        throw BackupImportException(BackupImportErrorCode.invalidBackup, error);
      }
    });
  }

  @override
  Future<BackupImportResult> importBackup(
    BackupImportPreview preview,
    BackupImportMode mode,
  ) {
    return _exclusive(() async {
      final session = _sessions[preview.sessionId];
      if (session == null) {
        throw const BackupImportException(BackupImportErrorCode.invalidBackup);
      }

      Directory? importedMediaDirectory;
      try {
        final data = _readBackupData(session);
        final currentDiaryRows = await _database.database.query(
          'diary_entries',
          columns: ['id', 'title', 'plain_content', 'created_at'],
        );
        final currentDates = _writtenDiaryDateKeys(currentDiaryRows);
        final selectedDiaries = mode == BackupImportMode.overwrite
            ? data.diaries
            : data.diaries
                  .where(
                    (row) => !currentDates.contains(
                      _dateKey(_requiredInt(row, 'created_at')),
                    ),
                  )
                  .toList(growable: false);
        final selectedDiaryIds = selectedDiaries
            .map((row) => _requiredString(row, 'id'))
            .toSet();

        final documentsDirectory = await _loadDocumentsDirectory();
        importedMediaDirectory = Directory(
          p.join(documentsDirectory.path, 'media', 'imports', session.id),
        );
        final neededAssets = _collectNeededAssets(
          data,
          selectedDiaryIds: selectedDiaryIds,
          includeArchives: mode == BackupImportMode.overwrite,
        );
        final assets = _extractAssets(
          session,
          destinationDirectory: importedMediaDirectory,
          neededPaths: neededAssets,
        );

        final result = mode == BackupImportMode.overwrite
            ? await _overwrite(data, assets)
            : await _importIncrementally(
                data,
                selectedDiaries,
                selectedDiaryIds,
                assets,
              );
        if (mode == BackupImportMode.overwrite) {
          await _cleanupSupersededMedia(documentsDirectory, session.id);
        }
        _sessions.remove(session.id);
        await _deleteDirectory(session.directory);
        return result;
      } on BackupImportException {
        if (importedMediaDirectory != null) {
          await _deleteDirectory(importedMediaDirectory);
        }
        rethrow;
      } on Object catch (error) {
        if (importedMediaDirectory != null) {
          await _deleteDirectory(importedMediaDirectory);
        }
        throw BackupImportException(BackupImportErrorCode.importFailed, error);
      }
    });
  }

  @override
  Future<void> discardPreview(BackupImportPreview preview) async {
    final session = _sessions.remove(preview.sessionId);
    if (session != null) await _deleteDirectory(session.directory);
  }

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (_isBusy) {
      throw const BackupImportException(
        BackupImportErrorCode.transferInProgress,
      );
    }
    _isBusy = true;
    try {
      return await action();
    } finally {
      _isBusy = false;
    }
  }

  _InspectedBackup _extractAndInspect({
    required String sourcePath,
    required Directory sessionDirectory,
  }) {
    final input = InputFileStream(sourcePath);
    try {
      final archive = ZipDecoder().decodeStream(input, verify: true);
      final entries = _validatedEntries(archive);
      final layout = _findLayout(entries);
      final metadataEntry = entries[layout.path('metadata.json')];
      if (metadataEntry == null || !metadataEntry.isFile) {
        throw const BackupImportException(BackupImportErrorCode.invalidBackup);
      }
      final metadata = _parseMetadata(_readJson(metadataEntry));
      final keyEntries = _backupKeyFileNames
          .map((fileName) => entries[layout.path(fileName)])
          .whereType<ArchiveFile>()
          .where((entry) => entry.isFile)
          .toList(growable: false);
      if (keyEntries.isEmpty) {
        throw const BackupImportException(BackupImportErrorCode.missingKeyFile);
      }
      if (keyEntries.length != 1) {
        throw const BackupImportException(BackupImportErrorCode.invalidBackup);
      }
      final keyHex = _parseKey(_readJson(keyEntries.single));
      final databaseEntry = entries[layout.path('diary.db')]!;
      final databasePath = p.join(sessionDirectory.path, 'diary.db');
      final output = OutputFileStream(databasePath);
      try {
        databaseEntry.writeContent(output);
      } finally {
        output.closeSync();
      }

      final database = _openBackupDatabase(databasePath, keyHex);
      try {
        _validateBackupSchema(database);
        final diaryRows = database.select(
          'SELECT id, created_at FROM diary_entries',
        );
        final diaryCreatedAt = diaryRows
            .map((row) => _requiredInt(row, 'created_at'))
            .toList(growable: false);
        final archiveCount = _singleCount(database, 'archives');
        final attachmentRows = database.select(
          'SELECT file_path FROM attachments',
        );
        for (final row in attachmentRows) {
          _validateAttachmentPath(_requiredString(row, 'file_path'));
        }
        final foreignKeyFailures = database.select('PRAGMA foreign_key_check');
        if (foreignKeyFailures.isNotEmpty) {
          throw const BackupImportException(
            BackupImportErrorCode.invalidBackup,
          );
        }
        final mediaFileCount = entries.entries.where((entry) {
          if (!entry.value.isFile) return false;
          final relative = layout.relativePath(entry.key);
          return relative.startsWith('images/') ||
              relative.startsWith('thumbnails/');
        }).length;
        return _InspectedBackup(
          metadata: metadata,
          rootPrefix: layout.rootPrefix,
          databasePath: databasePath,
          keyHex: keyHex,
          diaryCreatedAt: diaryCreatedAt,
          archiveCount: archiveCount,
          attachmentCount: attachmentRows.length,
          mediaFileCount: mediaFileCount,
        );
      } finally {
        database.close();
      }
    } on BackupImportException {
      rethrow;
    } on Object catch (error) {
      throw BackupImportException(BackupImportErrorCode.invalidBackup, error);
    } finally {
      input.closeSync();
    }
  }

  _BackupData _readBackupData(_BackupSession session) {
    final database = _openBackupDatabase(session.databasePath, session.keyHex);
    try {
      _validateBackupSchema(database);
      final data = _BackupData(
        diaries: _rows(database, 'diary_entries'),
        tags: _rows(database, 'tags'),
        diaryTags: _rows(database, 'diary_tags'),
        attachments: _rows(database, 'attachments'),
        archives: _rows(database, 'archives'),
        imageRefs: _rows(database, 'image_refs'),
        personMentionStats: _rows(database, 'person_mention_stats'),
        mediaSourceRefs: _rows(database, 'media_source_refs'),
      );
      for (final row in data.attachments) {
        _validateAttachmentPath(_requiredString(row, 'file_path'));
      }
      return data;
    } on BackupImportException {
      rethrow;
    } on Object catch (error) {
      throw BackupImportException(BackupImportErrorCode.invalidBackup, error);
    } finally {
      database.close();
    }
  }

  Future<BackupImportResult> _overwrite(
    _BackupData data,
    _ImportedAssets assets,
  ) async {
    await _database.database.transaction((transaction) async {
      await transaction.delete('diary_tags');
      await transaction.delete('attachments');
      await transaction.delete('tags');
      await transaction.delete('diary_entries');
      await transaction.delete('person_mention_stats');
      await transaction.delete('archives');
      await transaction.delete('image_refs');
      await transaction.delete('media_source_refs');

      for (final row in data.diaries) {
        await transaction.insert('diary_entries', _diaryValues(row, assets));
      }
      for (final row in data.tags) {
        await transaction.insert('tags', _tagValues(row));
      }
      for (final row in data.diaryTags) {
        await transaction.insert('diary_tags', _diaryTagValues(row));
      }
      for (final row in data.attachments) {
        await transaction.insert('attachments', _attachmentValues(row, assets));
      }
      for (final row in data.archives) {
        await transaction.insert('archives', _archiveValues(row, assets));
      }
      for (final row in data.imageRefs) {
        await transaction.insert('image_refs', _imageRefValues(row));
      }
      for (final row in data.personMentionStats) {
        await transaction.insert(
          'person_mention_stats',
          _personMentionValues(row),
        );
      }
      for (final row in data.mediaSourceRefs) {
        await transaction.insert(
          'media_source_refs',
          _mediaSourceValues(row, assets),
        );
      }
    });
    return BackupImportResult(
      importedDiaryCount: data.diaries.length,
      importedArchiveCount: data.archives.length,
      skippedDiaryCount: 0,
    );
  }

  Future<BackupImportResult> _importIncrementally(
    _BackupData data,
    List<Map<String, Object?>> selectedDiaries,
    Set<String> selectedDiaryIds,
    _ImportedAssets assets,
  ) async {
    await _database.database.transaction((transaction) async {
      final existingDiaryRows = await transaction.query(
        'diary_entries',
        columns: ['id'],
      );
      final usedDiaryIds = existingDiaryRows
          .map((row) => _requiredString(row, 'id'))
          .toSet();
      final diaryIdMap = <String, String>{};
      for (final row in selectedDiaries) {
        final sourceId = _requiredString(row, 'id');
        final destinationId = _uniqueId(sourceId, usedDiaryIds);
        diaryIdMap[sourceId] = destinationId;
        await transaction.insert(
          'diary_entries',
          _diaryValues(row, assets, id: destinationId),
        );
      }

      final selectedLinks = data.diaryTags
          .where(
            (row) =>
                selectedDiaryIds.contains(_requiredString(row, 'diary_id')),
          )
          .toList(growable: false);
      final usedBackupTagIds = selectedLinks
          .map((row) => _requiredInt(row, 'tag_id'))
          .toSet();
      final existingTagRows = await transaction.query('tags');
      final tagIdsByName = <String, int>{
        for (final row in existingTagRows)
          _requiredString(row, 'name'): _requiredInt(row, 'id'),
      };
      final destinationTagIds = <int, int>{};
      for (final row in data.tags) {
        final sourceId = _requiredInt(row, 'id');
        if (!usedBackupTagIds.contains(sourceId)) continue;
        final name = _requiredString(row, 'name');
        final destinationId =
            tagIdsByName[name] ??
            await transaction.insert('tags', {'name': name});
        tagIdsByName[name] = destinationId;
        destinationTagIds[sourceId] = destinationId;
      }
      for (final row in selectedLinks) {
        final sourceDiaryId = _requiredString(row, 'diary_id');
        final sourceTagId = _requiredInt(row, 'tag_id');
        final destinationTagId = destinationTagIds[sourceTagId];
        if (destinationTagId == null) {
          throw const BackupImportException(
            BackupImportErrorCode.invalidBackup,
          );
        }
        await transaction.insert('diary_tags', {
          'diary_id': diaryIdMap[sourceDiaryId]!,
          'tag_id': destinationTagId,
        });
      }

      final existingAttachmentRows = await transaction.query(
        'attachments',
        columns: ['id'],
      );
      final usedAttachmentIds = existingAttachmentRows
          .map((row) => _requiredString(row, 'id'))
          .toSet();
      for (final row in data.attachments) {
        final sourceDiaryId = _requiredString(row, 'diary_id');
        if (!selectedDiaryIds.contains(sourceDiaryId)) continue;
        final sourceId = _requiredString(row, 'id');
        await transaction.insert(
          'attachments',
          _attachmentValues(
            row,
            assets,
            id: _uniqueId(sourceId, usedAttachmentIds),
            diaryId: diaryIdMap[sourceDiaryId],
          ),
        );
      }
    });

    return BackupImportResult(
      importedDiaryCount: selectedDiaries.length,
      importedArchiveCount: 0,
      skippedDiaryCount: data.diaries.length - selectedDiaries.length,
    );
  }

  Set<String> _collectNeededAssets(
    _BackupData data, {
    required Set<String> selectedDiaryIds,
    required bool includeArchives,
  }) {
    final needed = <String>{};
    for (final row in data.diaries) {
      if (!selectedDiaryIds.contains(_requiredString(row, 'id'))) continue;
      needed.addAll(_imageAssetPaths(_requiredString(row, 'content')));
    }
    for (final row in data.attachments) {
      if (!selectedDiaryIds.contains(_requiredString(row, 'diary_id'))) {
        continue;
      }
      needed.add(_validateAttachmentPath(_requiredString(row, 'file_path')));
    }
    if (includeArchives) {
      for (final row in data.archives) {
        final mainImage = row['main_image'];
        if (mainImage is String) needed.addAll(_imageAssetPaths(mainImage));
        final rawImages = row['images'];
        if (rawImages is String && rawImages.isNotEmpty) {
          final images = _decodeStringList(rawImages);
          for (final image in images) {
            needed.addAll(_imageAssetPaths(image));
          }
        }
      }
      for (final row in data.mediaSourceRefs) {
        needed.addAll(_imageAssetPaths(_requiredString(row, 'image_path')));
        needed.addAll(_imageAssetPaths(_requiredString(row, 'preview_path')));
      }
    }
    return needed;
  }

  _ImportedAssets _extractAssets(
    _BackupSession session, {
    required Directory destinationDirectory,
    required Set<String> neededPaths,
  }) {
    if (neededPaths.isEmpty) return const _ImportedAssets({});
    destinationDirectory.createSync(recursive: true);
    final input = InputFileStream(session.sourcePath);
    try {
      final archive = ZipDecoder().decodeStream(input, verify: true);
      final entries = _validatedEntries(archive);
      final extracted = <String, String>{};
      for (final relativePath in neededPaths) {
        final entry = entries['${session.rootPrefix}$relativePath'];
        if (entry == null || !entry.isFile) {
          throw const BackupImportException(
            BackupImportErrorCode.invalidBackup,
          );
        }
        final destinationPath = p.joinAll([
          destinationDirectory.path,
          ...relativePath.split('/'),
        ]);
        Directory(p.dirname(destinationPath)).createSync(recursive: true);
        final output = OutputFileStream(destinationPath);
        try {
          entry.writeContent(output);
        } finally {
          output.closeSync();
        }
        extracted[relativePath] = p.normalize(p.absolute(destinationPath));
      }
      return _ImportedAssets(extracted);
    } on BackupImportException {
      rethrow;
    } on Object catch (error) {
      throw BackupImportException(BackupImportErrorCode.invalidBackup, error);
    } finally {
      input.closeSync();
    }
  }

  Future<Set<int>> _loadLocalDiaryDates() async {
    final rows = await _database.database.query(
      'diary_entries',
      columns: ['title', 'plain_content', 'created_at'],
    );
    return _writtenDiaryDateKeys(rows);
  }

  Future<void> _cleanupSupersededMedia(
    Directory documentsDirectory,
    String retainedImportId,
  ) async {
    final mediaDirectory = Directory(p.join(documentsDirectory.path, 'media'));
    await _deleteDirectory(Directory(p.join(mediaDirectory.path, 'diary')));
    await _deleteDirectory(Directory(p.join(mediaDirectory.path, 'archive')));

    final importsDirectory = Directory(p.join(mediaDirectory.path, 'imports'));
    try {
      if (!await importsDirectory.exists()) return;
      await for (final entity in importsDirectory.list(followLinks: false)) {
        if (entity is Directory &&
            p.basename(entity.path) != retainedImportId) {
          await _deleteDirectory(entity);
        }
      }
    } on FileSystemException {
      // Imported database state is already committed. Stale media is harmless.
    }
  }

  Future<void> _discardAllSessions() async {
    final sessions = _sessions.values.toList(growable: false);
    _sessions.clear();
    for (final session in sessions) {
      await _deleteDirectory(session.directory);
    }
  }

  String _uniqueId(String preferred, Set<String> usedIds) {
    var candidate = preferred;
    while (!usedIds.add(candidate)) {
      candidate = _uuid.v4();
    }
    return candidate;
  }

  static Future<PickedBackupFile?> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: false,
      withData: false,
    );
    if (result == null) return null;
    final file = result.files.single;
    final path = file.path;
    if (path == null || path.isEmpty) {
      throw const BackupImportException(BackupImportErrorCode.unreadableFile);
    }
    return PickedBackupFile(path: path, name: file.name);
  }
}

Map<String, ArchiveFile> _validatedEntries(Archive archive) {
  final entries = <String, ArchiveFile>{};
  for (final entry in archive) {
    if (entry.isSymbolicLink) {
      throw const BackupImportException(BackupImportErrorCode.invalidBackup);
    }
    final normalized = _normalizeArchivePath(entry.name);
    if (entries.containsKey(normalized)) {
      throw const BackupImportException(BackupImportErrorCode.invalidBackup);
    }
    entries[normalized] = entry;
  }
  return entries;
}

String _normalizeArchivePath(String value) {
  final replaced = value.replaceAll('\\', '/');
  if (replaced.isEmpty ||
      replaced.startsWith('/') ||
      RegExp(r'^[A-Za-z]:').hasMatch(replaced)) {
    throw const BackupImportException(BackupImportErrorCode.invalidBackup);
  }
  final segments = replaced
      .split('/')
      .where((part) => part.isNotEmpty)
      .toList();
  if (segments.isEmpty || segments.any((part) => part == '.' || part == '..')) {
    throw const BackupImportException(BackupImportErrorCode.invalidBackup);
  }
  return segments.join('/');
}

_ArchiveLayout _findLayout(Map<String, ArchiveFile> entries) {
  final candidates = entries.entries
      .where((entry) {
        if (!entry.value.isFile) return false;
        final segments = entry.key.split('/');
        return segments.last == 'diary.db' && segments.length <= 3;
      })
      .toList(growable: false);
  if (candidates.length != 1) {
    throw const BackupImportException(BackupImportErrorCode.invalidBackup);
  }
  final segments = candidates.single.key.split('/')..removeLast();
  final prefix = segments.isEmpty ? '' : '${segments.join('/')}/';
  return _ArchiveLayout(prefix);
}

Map<String, Object?> _readJson(ArchiveFile entry) {
  if (entry.size > 1024 * 1024) {
    throw const BackupImportException(BackupImportErrorCode.invalidBackup);
  }
  final bytes = entry.readBytes();
  if (bytes == null) {
    throw const BackupImportException(BackupImportErrorCode.invalidBackup);
  }
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map) {
    throw const BackupImportException(BackupImportErrorCode.invalidBackup);
  }
  return decoded.cast<String, Object?>();
}

_BackupMetadata _parseMetadata(Map<String, Object?> json) {
  final rawVersion = json['backupFormatVersion'];
  if (rawVersion is! num || rawVersion != backupFormatVersion) {
    throw const BackupImportException(
      BackupImportErrorCode.unsupportedBackupFormat,
    );
  }
  final appName = json['appName'];
  final appVersion = json['appVersion'];
  final exportedAtRaw = json['exportedAt'];
  final compression = json['compression'];
  final encryption = json['encryption'];
  final exportedAt = exportedAtRaw is String
      ? DateTime.tryParse(exportedAtRaw)
      : null;
  if (appName is! String ||
      appName.trim().isEmpty ||
      appVersion is! String ||
      appVersion.trim().isEmpty ||
      exportedAt == null ||
      compression != 'zip' ||
      encryption is! Map ||
      encryption['db'] != 'sqlcipher' ||
      encryption['keyFile'] != 'plain-text' ||
      encryption['attachments'] != 'plain-zip') {
    throw const BackupImportException(BackupImportErrorCode.invalidBackup);
  }
  return _BackupMetadata(
    appName: appName,
    appVersion: appVersion,
    exportedAt: exportedAt,
    formatVersion: rawVersion.toInt(),
  );
}

String _parseKey(Map<String, Object?> json) {
  final key = json['dbKeyHex'];
  if (json['version'] != 1 ||
      json['format'] != 'plain-text' ||
      key is! String ||
      !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(key)) {
    throw const BackupImportException(BackupImportErrorCode.invalidBackup);
  }
  return key.toLowerCase();
}

sqlite.Database _openBackupDatabase(String path, String keyHex) {
  sqlite.Database? database;
  try {
    database = sqlite.sqlite3.open(path, mode: sqlite.OpenMode.readOnly);
    database.execute('PRAGMA key = "x\'$keyHex\'"');
    database.execute('PRAGMA cipher_page_size = 4096');
    database.execute('PRAGMA kdf_iter = 256000');
    database.execute('PRAGMA cipher_hmac_algorithm = HMAC_SHA512');
    database.execute('PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA512');
    database.select('SELECT COUNT(*) FROM sqlite_master');
    return database;
  } on Object catch (error) {
    database?.close();
    throw BackupImportException(BackupImportErrorCode.invalidBackup, error);
  }
}

void _validateBackupSchema(sqlite.Database database) {
  const requiredTables = {
    'diary_entries',
    'tags',
    'diary_tags',
    'attachments',
    'archives',
    'settings',
    'image_refs',
    'person_mention_stats',
    'media_source_refs',
  };
  final tableNames = database
      .select("SELECT name FROM sqlite_master WHERE type = 'table'")
      .map((row) => row['name'])
      .whereType<String>()
      .toSet();
  if (!tableNames.containsAll(requiredTables)) {
    throw const BackupImportException(BackupImportErrorCode.invalidBackup);
  }
}

int _singleCount(sqlite.Database database, String table) {
  final row = database.select('SELECT COUNT(*) AS count FROM $table').single;
  return _requiredInt(row, 'count');
}

List<Map<String, Object?>> _rows(sqlite.Database database, String table) {
  return database
      .select('SELECT * FROM $table')
      .map((row) => Map<String, Object?>.from(row))
      .toList(growable: false);
}

String _validateAttachmentPath(String value) {
  const uuid =
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';
  if (!RegExp(
    '^attachments/$uuid(?:\\.[A-Za-z0-9]{1,16})?\$',
  ).hasMatch(value)) {
    throw const BackupImportException(BackupImportErrorCode.invalidBackup);
  }
  return value;
}

Map<String, Object?> _diaryValues(
  Map<String, Object?> row,
  _ImportedAssets assets, {
  String? id,
}) {
  return {
    'id': id ?? _requiredString(row, 'id'),
    'title': _requiredString(row, 'title'),
    'content': assets.rewriteDiaryContent(_requiredString(row, 'content')),
    'plain_content': _requiredString(row, 'plain_content'),
    'mood': _requiredString(row, 'mood'),
    'weather': _nullableString(row, 'weather'),
    'created_at': _requiredInt(row, 'created_at'),
    'updated_at': _requiredInt(row, 'updated_at'),
  };
}

Map<String, Object?> _tagValues(Map<String, Object?> row) => {
  'id': _requiredInt(row, 'id'),
  'name': _requiredString(row, 'name'),
};

Map<String, Object?> _diaryTagValues(Map<String, Object?> row) => {
  'diary_id': _requiredString(row, 'diary_id'),
  'tag_id': _requiredInt(row, 'tag_id'),
};

Map<String, Object?> _attachmentValues(
  Map<String, Object?> row,
  _ImportedAssets assets, {
  String? id,
  String? diaryId,
}) {
  final sourcePath = _validateAttachmentPath(_requiredString(row, 'file_path'));
  return {
    'id': id ?? _requiredString(row, 'id'),
    'diary_id': diaryId ?? _requiredString(row, 'diary_id'),
    'filename': _requiredString(row, 'filename'),
    'mime_type': _requiredString(row, 'mime_type'),
    'file_path': assets.requiredFilePath(sourcePath),
    'size': _requiredInt(row, 'size'),
    'created_at': _requiredInt(row, 'created_at'),
  };
}

Map<String, Object?> _archiveValues(
  Map<String, Object?> row,
  _ImportedAssets assets,
) {
  final rawImages = _nullableString(row, 'images');
  final images = rawImages == null
      ? null
      : jsonEncode(
          _decodeStringList(
            rawImages,
          ).map(assets.rewriteArchivePath).toList(growable: false),
        );
  final mainImage = _nullableString(row, 'main_image');
  return {
    'id': _requiredString(row, 'id'),
    'name': _requiredString(row, 'name'),
    'alias': _nullableString(row, 'alias'),
    'description': _nullableString(row, 'description'),
    'type': _requiredString(row, 'type'),
    'main_image': mainImage == null
        ? null
        : assets.rewriteArchivePath(mainImage),
    'images': images,
    'created_at': _requiredInt(row, 'created_at'),
    'updated_at': _requiredInt(row, 'updated_at'),
  };
}

Map<String, Object?> _imageRefValues(Map<String, Object?> row) => {
  'image_id': _requiredString(row, 'image_id'),
  'ref_count': _requiredInt(row, 'ref_count'),
  'updated_at': _requiredInt(row, 'updated_at'),
};

Map<String, Object?> _personMentionValues(Map<String, Object?> row) => {
  'archive_id': _requiredString(row, 'archive_id'),
  'mention_count': _requiredInt(row, 'mention_count'),
  'updated_at': _requiredInt(row, 'updated_at'),
};

Map<String, Object?> _mediaSourceValues(
  Map<String, Object?> row,
  _ImportedAssets assets,
) => {
  'image_id': _requiredString(row, 'image_id'),
  'source_type': _requiredString(row, 'source_type'),
  'source_id': _requiredString(row, 'source_id'),
  'source_title': _requiredString(row, 'source_title'),
  'source_created_at': _requiredInt(row, 'source_created_at'),
  'source_updated_at': _requiredInt(row, 'source_updated_at'),
  'image_path': assets.rewriteDiaryContent(_requiredString(row, 'image_path')),
  'preview_path': assets.rewriteDiaryContent(
    _requiredString(row, 'preview_path'),
  ),
};

String _requiredString(Map<Object?, Object?> row, String key) {
  final value = row[key];
  if (value is! String) {
    throw const BackupImportException(BackupImportErrorCode.invalidBackup);
  }
  return value;
}

String? _nullableString(Map<Object?, Object?> row, String key) {
  final value = row[key];
  if (value == null) return null;
  if (value is! String) {
    throw const BackupImportException(BackupImportErrorCode.invalidBackup);
  }
  return value;
}

int _requiredInt(Map<Object?, Object?> row, String key) {
  final value = row[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw const BackupImportException(BackupImportErrorCode.invalidBackup);
}

List<String> _decodeStringList(String value) {
  final decoded = jsonDecode(value);
  if (decoded is! List || decoded.any((item) => item is! String)) {
    throw const BackupImportException(BackupImportErrorCode.invalidBackup);
  }
  return decoded.cast<String>();
}

const _uuidPattern =
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';
final RegExp _backupImageUri = RegExp(
  'diary-image://($_uuidPattern(?:_thumb)?\\.(?:webp|png|jpe?g))'
  r'(?![A-Za-z0-9._-])',
  caseSensitive: false,
);
final RegExp _thumbnailImageName = RegExp(
  r'_thumb\.[^.]+$',
  caseSensitive: false,
);

String _imageAssetPath(String fileName) =>
    _thumbnailImageName.hasMatch(fileName)
    ? 'thumbnails/$fileName'
    : 'images/$fileName';

Iterable<String> _imageAssetPaths(String value) sync* {
  for (final match in _backupImageUri.allMatches(value)) {
    yield _imageAssetPath(match.group(1)!);
  }
}

int _dateKey(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  return date.year * 10000 + date.month * 100 + date.day;
}

Set<int> _writtenDiaryDateKeys(Iterable<Map<String, Object?>> rows) {
  return rows
      .where(
        (row) => hasWrittenDiaryContent(
          title: _requiredString(row, 'title'),
          plainContent: _requiredString(row, 'plain_content'),
        ),
      )
      .map((row) => _dateKey(_requiredInt(row, 'created_at')))
      .toSet();
}

Future<void> _deleteDirectory(Directory directory) async {
  try {
    if (await directory.exists()) await directory.delete(recursive: true);
  } on FileSystemException {
    // Temporary and superseded media can be cleaned on a later app launch.
  }
}

class _ImportedAssets {
  const _ImportedAssets(this.paths);

  final Map<String, String> paths;

  String requiredFilePath(String sourcePath) {
    final path = paths[sourcePath];
    if (path == null) {
      throw const BackupImportException(BackupImportErrorCode.invalidBackup);
    }
    return path;
  }

  String rewriteDiaryContent(String value) {
    return value.replaceAllMapped(_backupImageUri, (match) {
      final fileName = match.group(1)!;
      final relativePath = _imageAssetPath(fileName);
      final path = paths[relativePath];
      if (path == null) {
        throw const BackupImportException(BackupImportErrorCode.invalidBackup);
      }
      return Uri.file(path).toString();
    });
  }

  String rewriteArchivePath(String value) {
    final match = _backupImageUri.firstMatch(value);
    if (match == null || match.group(0) != value) return value;
    return requiredFilePath(_imageAssetPath(match.group(1)!));
  }
}

class _ArchiveLayout {
  const _ArchiveLayout(this.rootPrefix);

  final String rootPrefix;

  String path(String relativePath) => '$rootPrefix$relativePath';

  String relativePath(String archivePath) {
    return archivePath.startsWith(rootPrefix)
        ? archivePath.substring(rootPrefix.length)
        : archivePath;
  }
}

class _BackupMetadata {
  const _BackupMetadata({
    required this.appName,
    required this.appVersion,
    required this.exportedAt,
    required this.formatVersion,
  });

  final String appName;
  final String appVersion;
  final DateTime exportedAt;
  final int formatVersion;
}

class _InspectedBackup {
  const _InspectedBackup({
    required this.metadata,
    required this.rootPrefix,
    required this.databasePath,
    required this.keyHex,
    required this.diaryCreatedAt,
    required this.archiveCount,
    required this.attachmentCount,
    required this.mediaFileCount,
  });

  final _BackupMetadata metadata;
  final String rootPrefix;
  final String databasePath;
  final String keyHex;
  final List<int> diaryCreatedAt;
  final int archiveCount;
  final int attachmentCount;
  final int mediaFileCount;
}

class _BackupSession {
  const _BackupSession({
    required this.id,
    required this.sourcePath,
    required this.directory,
    required this.rootPrefix,
    required this.databasePath,
    required this.keyHex,
  });

  final String id;
  final String sourcePath;
  final Directory directory;
  final String rootPrefix;
  final String databasePath;
  final String keyHex;
}

class _BackupData {
  const _BackupData({
    required this.diaries,
    required this.tags,
    required this.diaryTags,
    required this.attachments,
    required this.archives,
    required this.imageRefs,
    required this.personMentionStats,
    required this.mediaSourceRefs,
  });

  final List<Map<String, Object?>> diaries;
  final List<Map<String, Object?>> tags;
  final List<Map<String, Object?>> diaryTags;
  final List<Map<String, Object?>> attachments;
  final List<Map<String, Object?>> archives;
  final List<Map<String, Object?>> imageRefs;
  final List<Map<String, Object?>> personMentionStats;
  final List<Map<String, Object?>> mediaSourceRefs;
}
