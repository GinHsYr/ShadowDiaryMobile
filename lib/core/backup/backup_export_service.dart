import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../database/app_database.dart';
import '../services/diary_image_store.dart';
import '../app_info.dart';

const backupFilePrefix = 'shadow-diary-backup';
const backupExportFormatVersion = 5;

final backupExportServiceProvider = Provider<BackupExportService>((ref) {
  return const UnavailableBackupExportService();
});

enum BackupExportErrorCode {
  unavailable,
  invalidDatabase,
  unreadableFile,
  transferInProgress,
  exportFailed,
}

class BackupExportException implements Exception {
  const BackupExportException(this.code, [this.cause]);

  final BackupExportErrorCode code;
  final Object? cause;

  @override
  String toString() => 'BackupExportException($code, $cause)';
}

class BackupExportResult {
  const BackupExportResult({required this.path});

  final String path;
}

abstract interface class BackupExportService {
  Future<BackupExportResult?> exportBackup();
}

class UnavailableBackupExportService implements BackupExportService {
  const UnavailableBackupExportService();

  @override
  Future<BackupExportResult?> exportBackup() {
    throw const BackupExportException(BackupExportErrorCode.unavailable);
  }
}

typedef SaveBackupFile = Future<String?> Function(String fileName, File source);

class DeviceBackupExportService implements BackupExportService {
  DeviceBackupExportService(
    this._database, {
    required this._imageStore,
    SaveBackupFile? saveBackupFile,
    this.appName = 'ShadowDiary',
    this.appVersion = AppInfo.version,
    Random? random,
  }) : _saveBackupFile = saveBackupFile ?? _saveFile,
       _random = random ?? Random.secure();

  final AppDatabase _database;
  final DiaryImageStore _imageStore;
  final SaveBackupFile _saveBackupFile;
  final String appName;
  final String appVersion;
  final Random _random;

  bool _isBusy = false;

  @override
  Future<BackupExportResult?> exportBackup() async {
    if (_isBusy) {
      throw const BackupExportException(
        BackupExportErrorCode.transferInProgress,
      );
    }
    _isBusy = true;
    try {
      final fileName =
          '$backupFilePrefix-${_formatTimestamp(DateTime.now())}.zip';
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'shadow_diary_export_',
      );
      try {
        await _database.database.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
        final keyHex = _randomKeyHex();
        final databasePath = p.join(temporaryDirectory.path, 'diary.db');
        await File(_database.path).copy(databasePath);
        _sanitizeDatabase(databasePath);
        _encryptDatabase(databasePath, keyHex);

        final zipPath = p.join(temporaryDirectory.path, fileName);
        await _createArchive(File(zipPath), File(databasePath), keyHex);
        final selectedPath = await _saveBackupFile(fileName, File(zipPath));
        if (selectedPath == null || selectedPath.trim().isEmpty) return null;
        return BackupExportResult(path: _withZipExtension(selectedPath));
      } finally {
        await _deleteDirectory(temporaryDirectory);
      }
    } on BackupExportException {
      rethrow;
    } on FileSystemException catch (error) {
      throw BackupExportException(BackupExportErrorCode.unreadableFile, error);
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Backup export failed: $error\n$stackTrace');
      }
      throw BackupExportException(BackupExportErrorCode.exportFailed, error);
    } finally {
      _isBusy = false;
    }
  }

  Future<void> _createArchive(
    File destination,
    File database,
    String keyHex,
  ) async {
    final encoder = ZipFileEncoder();
    encoder.create(destination.path);
    try {
      await encoder.addFile(database, 'diary.db');
      await _addDirectoryFiles(encoder, _imageStore.imageDirectory, 'images');
      await _addDirectoryFiles(
        encoder,
        _imageStore.thumbnailDirectory,
        'thumbnails',
      );
      await _addAttachmentFiles(encoder);
      encoder.addArchiveFile(
        ArchiveFile.string(
          'metadata.json',
          jsonEncode({
            'appName': appName,
            'appVersion': appVersion,
            'exportedAt': DateTime.now().toUtc().toIso8601String(),
            'backupFormatVersion': backupExportFormatVersion,
            'compression': 'zip',
            'encryption': {
              'db': 'sqlcipher',
              'keyFile': 'plain-text',
              'attachments': 'plain-zip',
            },
          }),
        ),
      );
      encoder.addArchiveFile(
        ArchiveFile.string(
          'backup-key.json',
          jsonEncode({
            'version': 1,
            'format': 'plain-text',
            'dbKeyHex': keyHex,
          }),
        ),
      );
    } finally {
      await encoder.close();
    }
  }

  Future<void> _addDirectoryFiles(
    ZipFileEncoder encoder,
    Directory directory,
    String archiveDirectory,
  ) async {
    if (!await directory.exists()) return;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final relativePath = p.relative(entity.path, from: directory.path);
      if (relativePath.startsWith('..') || p.isAbsolute(relativePath)) {
        throw const BackupExportException(
          BackupExportErrorCode.invalidDatabase,
        );
      }
      await encoder.addFile(
        entity,
        p.posix.join(archiveDirectory, p.split(relativePath).join('/')),
      );
    }
  }

  Future<void> _addAttachmentFiles(ZipFileEncoder encoder) async {
    final documentsDirectory = _imageStore.documentsDirectory;
    if (documentsDirectory == null) return;
    final rows = await _database.database.query('attachments');
    for (final row in rows) {
      final storedPath = row['file_path'];
      if (storedPath is! String || !_isSafeAttachmentPath(storedPath)) {
        throw const BackupExportException(
          BackupExportErrorCode.invalidDatabase,
        );
      }
      final source = File(p.join(documentsDirectory.path, storedPath));
      if (!await source.exists()) {
        throw const BackupExportException(BackupExportErrorCode.unreadableFile);
      }
      await encoder.addFile(source, storedPath.replaceAll('\\', '/'));
    }
  }

  String _randomKeyHex() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<String?> _saveFile(String fileName, File source) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const MethodChannel(
        'com.shadowdiary.hsyr/backup_export',
      ).invokeMethod<String>('saveTemporaryZip', {
        'sourcePath': source.path,
        'suggestedName': fileName,
      });
    }
    final selectedPath = await FilePicker.saveFile(
      dialogTitle: 'Export backup',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (selectedPath == null || selectedPath.trim().isEmpty) return null;
    final destination = File(_withZipExtension(selectedPath));
    await source.copy(destination.path);
    return destination.path;
  }
}

String _formatTimestamp(DateTime value) {
  String pad(int number) => number.toString().padLeft(2, '0');

  return '${value.year}${pad(value.month)}${pad(value.day)}-'
      '${pad(value.hour)}${pad(value.minute)}${pad(value.second)}';
}

String _withZipExtension(String path) {
  return path.toLowerCase().endsWith('.zip') ? path : '$path.zip';
}

bool _isSafeAttachmentPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  return RegExp(
    r'^attachments/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}(?:\.[A-Za-z0-9]{1,16})?$',
  ).hasMatch(normalized);
}

void _encryptDatabase(String path, String keyHex) {
  sqlite.Database? database;
  try {
    database = sqlite.sqlite3.open(path);
    _configureCipher(database);
    database.execute('PRAGMA rekey = "x\'$keyHex\'"');
    database.select('SELECT COUNT(*) FROM sqlite_master');
  } finally {
    database?.close();
  }

  database = sqlite.sqlite3.open(path, mode: sqlite.OpenMode.readOnly);
  try {
    _configureCipher(database, keyHex);
    database.select('SELECT COUNT(*) FROM sqlite_master');
  } finally {
    database.close();
  }
}

void _sanitizeDatabase(String path) {
  final database = sqlite.sqlite3.open(path);
  try {
    database.execute(
      "DELETE FROM settings WHERE key LIKE 'security.%' OR key LIKE 'privacy.%' OR key LIKE 'disguise.%'",
    );
    database.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  } finally {
    database.close();
  }
}

void _configureCipher(sqlite.Database database, [String? keyHex]) {
  if (keyHex != null) {
    database.execute('PRAGMA key = "x\'$keyHex\'"');
  }
  database.execute('PRAGMA cipher_page_size = 4096');
  database.execute('PRAGMA kdf_iter = 256000');
  database.execute('PRAGMA cipher_hmac_algorithm = HMAC_SHA512');
  database.execute('PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA512');
}

Future<void> _deleteDirectory(Directory directory) async {
  try {
    if (await directory.exists()) await directory.delete(recursive: true);
  } on FileSystemException {
    // An OS cleanup pass can remove an interrupted temporary export later.
  }
}
