import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';

const diaryImageScheme = 'diary-image';
const diaryImageSchemePrefix = '$diaryImageScheme://';

final diaryImageStoreProvider = Provider<DiaryImageStore>((ref) {
  return const DiaryImageStore.unconfigured();
});

final diaryImageCleanupProvider = Provider<DiaryImageCleanup>((ref) {
  return const NoOpDiaryImageCleanup();
});

DiaryImageStore diaryImageStoreOf(BuildContext context) {
  try {
    return ProviderScope.containerOf(context).read(diaryImageStoreProvider);
  } on StateError {
    return const DiaryImageStore.unconfigured();
  }
}

final RegExp _diaryImageFileNamePattern = RegExp(
  r'^([a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12})'
  r'(?:(?:(_thumb)\.webp)|\.(webp|png|jpe?g))$',
  caseSensitive: false,
);

final RegExp _htmlImageSourcePattern = RegExp(
  r'''((?:src|data-src)\s*=\s*(["']))([^"']+)(\2)''',
  caseSensitive: false,
);

class DiaryImageSource {
  const DiaryImageSource({
    required this.imageId,
    required this.fileName,
    required this.extension,
    required this.isThumbnail,
  });

  final String imageId;
  final String fileName;
  final String extension;
  final bool isThumbnail;

  String get source => '$diaryImageSchemePrefix$fileName';
}

abstract interface class DiaryImageCleanup {
  Future<void> cleanupUnreferenced({Iterable<String>? candidates});
}

class NoOpDiaryImageCleanup implements DiaryImageCleanup {
  const NoOpDiaryImageCleanup();

  @override
  Future<void> cleanupUnreferenced({Iterable<String>? candidates}) async {}
}

class DatabaseDiaryImageCleanup implements DiaryImageCleanup {
  const DatabaseDiaryImageCleanup(this.store, this.database);

  final DiaryImageStore store;
  final AppDatabase database;

  @override
  Future<void> cleanupUnreferenced({Iterable<String>? candidates}) {
    return store.cleanupUnreferenced(database, candidates: candidates);
  }
}

DiaryImageSource? parseDiaryImageSource(String? source) {
  final normalized = source?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (!normalized.toLowerCase().startsWith(diaryImageSchemePrefix)) {
    return null;
  }

  final fileName = normalized.substring(diaryImageSchemePrefix.length);
  final match = _diaryImageFileNamePattern.firstMatch(fileName);
  if (match == null) return null;
  final imageId = match.group(1)!.toLowerCase();
  final isThumbnail = match.group(2) != null;
  final extension = isThumbnail ? 'webp' : match.group(3)!.toLowerCase();
  return DiaryImageSource(
    imageId: imageId,
    fileName: '$imageId${isThumbnail ? '_thumb' : ''}.$extension',
    extension: extension,
    isThumbnail: isThumbnail,
  );
}

DiaryImageSource? diaryImageSourceFromFileName(String fileName) {
  return parseDiaryImageSource(
    '$diaryImageSchemePrefix${p.basename(fileName)}',
  );
}

class DiaryImageStore {
  const DiaryImageStore(this.documentsDirectory);

  const DiaryImageStore.unconfigured() : documentsDirectory = null;

  final Directory? documentsDirectory;

  static Future<DiaryImageStore> loadDefault() async {
    return DiaryImageStore(await getApplicationDocumentsDirectory());
  }

  Directory get imageDirectory {
    return Directory(p.join(_requireDocumentsDirectory().path, 'images'));
  }

  Directory get thumbnailDirectory {
    return Directory(p.join(_requireDocumentsDirectory().path, 'thumbnails'));
  }

  Future<void> ensureDirectories() async {
    await Future.wait([
      imageDirectory.create(recursive: true),
      thumbnailDirectory.create(recursive: true),
    ]);
  }

  String sourceForFileName(String fileName) {
    final parsed = diaryImageSourceFromFileName(fileName);
    if (parsed == null) {
      throw FormatException('Invalid diary image filename: $fileName');
    }
    return parsed.source;
  }

  File fileForParsedSource(DiaryImageSource source) {
    final directory = source.isThumbnail ? thumbnailDirectory : imageDirectory;
    return File(p.join(directory.path, source.fileName));
  }

  File? fileForSource(String source) {
    final parsed = parseDiaryImageSource(source);
    if (parsed != null) {
      if (documentsDirectory == null) return null;
      return fileForParsedSource(parsed);
    }

    final localPath = localPathFromImageSource(source);
    return localPath == null ? null : File(localPath);
  }

  Future<File> writeAsset(String fileName, List<int> bytes) async {
    final parsed = diaryImageSourceFromFileName(fileName);
    if (parsed == null) {
      throw const FormatException('Invalid diary image asset identifier.');
    }
    await ensureDirectories();
    final target = fileForParsedSource(parsed);
    final temporary = File('${target.path}.part');
    await temporary.writeAsBytes(bytes, flush: true);
    if (await target.exists()) await target.delete();
    return temporary.rename(target.path);
  }

  Future<bool> isReferenced(AppDatabase appDatabase, String source) async {
    final parsed =
        parseDiaryImageSource(source) ??
        diaryImageSourceFromFileName(_fileNameFromSource(source) ?? '');
    if (parsed == null) return false;
    return (await _referencedImageIds(appDatabase)).contains(parsed.imageId);
  }

  Future<void> cleanupUnreferenced(
    AppDatabase appDatabase, {
    Iterable<String>? candidates,
  }) async {
    if (documentsDirectory == null) return;
    final referencedIds = await _referencedImageIds(appDatabase);
    final candidateIds = <String>{};
    if (candidates == null) {
      for (final directory in [imageDirectory, thumbnailDirectory]) {
        try {
          if (!await directory.exists()) continue;
          await for (final entity in directory.list(followLinks: false)) {
            if (entity is! File) continue;
            final parsed = diaryImageSourceFromFileName(
              p.basename(entity.path),
            );
            if (parsed != null) candidateIds.add(parsed.imageId);
          }
        } on FileSystemException {
          // Cleanup is best-effort and can be retried after the next save.
        }
      }
    } else {
      for (final source in candidates) {
        final parsed =
            parseDiaryImageSource(source) ??
            diaryImageSourceFromFileName(_fileNameFromSource(source) ?? '');
        if (parsed != null) candidateIds.add(parsed.imageId);
      }
    }

    for (final imageId in candidateIds.difference(referencedIds)) {
      for (final file in await filesForImageId(imageId)) {
        try {
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          // Orphaned files are harmless and can be retried later.
        }
      }
    }
  }

  Future<List<File>> filesForImageId(String imageId) async {
    final normalized = imageId.toLowerCase();
    if (!RegExp(
      r'^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
    ).hasMatch(normalized)) {
      return const [];
    }
    final files = <File>[];
    for (final directory in [imageDirectory, thumbnailDirectory]) {
      try {
        if (!await directory.exists()) continue;
        await for (final entity in directory.list(followLinks: false)) {
          if (entity is! File) continue;
          final parsed = diaryImageSourceFromFileName(p.basename(entity.path));
          if (parsed?.imageId == normalized) files.add(entity);
        }
      } on FileSystemException {
        // Return any files already discovered in the other managed directory.
      }
    }
    return List.unmodifiable(files);
  }

  Future<Set<String>> _referencedImageIds(AppDatabase appDatabase) async {
    final database = appDatabase.database;
    final ids = <String>{};
    final diaryRows = await database.query(
      'diary_entries',
      columns: ['content'],
    );
    for (final row in diaryRows) {
      for (final source in _imageSourcesFromHtml(row['content']! as String)) {
        final parsed =
            parseDiaryImageSource(source) ??
            diaryImageSourceFromFileName(_fileNameFromSource(source) ?? '');
        if (parsed != null) ids.add(parsed.imageId);
      }
    }
    final archiveRows = await database.query(
      'archives',
      columns: ['main_image', 'images'],
    );
    for (final row in archiveRows) {
      final sources = <String>[
        if (row['main_image'] case final String source) source,
        ..._decodeStringList(row['images']),
      ];
      for (final source in sources) {
        final parsed =
            parseDiaryImageSource(source) ??
            diaryImageSourceFromFileName(_fileNameFromSource(source) ?? '');
        if (parsed != null) ids.add(parsed.imageId);
      }
    }
    final conflictRows = await database.query(
      'sync_conflicts',
      columns: ['local_payload', 'remote_payload'],
    );
    for (final row in conflictRows) {
      for (final value in [row['local_payload'], row['remote_payload']]) {
        if (value is! String) continue;
        for (final match in RegExp(
          r'diary-image://([a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12})',
          caseSensitive: false,
        ).allMatches(value)) {
          ids.add(match.group(1)!.toLowerCase());
        }
      }
    }
    return ids;
  }

  Future<void> migrateLegacyReferences(AppDatabase appDatabase) async {
    await ensureDirectories();
    final database = appDatabase.database;
    final diaryRows = await database.query(
      'diary_entries',
      columns: ['id', 'content'],
    );
    final archiveRows = await database.query(
      'archives',
      columns: ['id', 'main_image', 'images'],
    );
    final mediaRows = await database.query(
      'media_source_refs',
      columns: [
        'image_id',
        'source_type',
        'source_id',
        'image_path',
        'preview_path',
      ],
    );

    final sources = <String>{};
    for (final row in diaryRows) {
      sources.addAll(_imageSourcesFromHtml(row['content']! as String));
    }
    for (final row in archiveRows) {
      if (row['main_image'] case final String source) sources.add(source);
      sources.addAll(_decodeStringList(row['images']));
    }
    for (final row in mediaRows) {
      sources.add(row['image_path']! as String);
      sources.add(row['preview_path']! as String);
    }

    Map<String, File>? legacyFiles;
    final replacements = <String, String>{};
    final migratedLegacyFiles = <String>{};
    for (final source in sources) {
      final parsed =
          parseDiaryImageSource(source) ??
          diaryImageSourceFromFileName(_fileNameFromSource(source) ?? '');
      if (parsed == null) continue;

      final target = fileForParsedSource(parsed);
      File? sourceFile;
      final localPath = localPathFromImageSource(source);
      if (localPath != null) {
        final candidate = File(localPath);
        if (await candidate.exists()) sourceFile = candidate;
      }

      if (!await target.exists() && sourceFile == null) {
        legacyFiles ??= await _legacyFilesByName();
        sourceFile = legacyFiles[parsed.fileName];
      }
      if (!await target.exists() && sourceFile != null) {
        final temporary = File('${target.path}.migration');
        try {
          await target.parent.create(recursive: true);
          if (await temporary.exists()) await temporary.delete();
          await sourceFile.copy(temporary.path);
          await temporary.rename(target.path);
        } on FileSystemException {
          try {
            if (await temporary.exists()) await temporary.delete();
          } on FileSystemException {
            // A stale migration file is ignored by the protocol resolver.
          }
          continue;
        }
      }
      if (!await target.exists()) continue;
      if (sourceFile != null &&
          !p.equals(sourceFile.path, target.path) &&
          !await _filesHaveSameContent(sourceFile, target)) {
        continue;
      }

      replacements[source] = parsed.source;
      if (sourceFile != null && !p.equals(sourceFile.path, target.path)) {
        migratedLegacyFiles.add(p.normalize(p.absolute(sourceFile.path)));
      }
    }

    if (replacements.isNotEmpty) {
      await database.transaction((transaction) async {
        for (final row in diaryRows) {
          final content = row['content']! as String;
          final migrated = _rewriteHtmlImageSources(content, replacements);
          if (migrated == content) continue;
          await transaction.update(
            'diary_entries',
            {'content': migrated},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
        for (final row in archiveRows) {
          final mainImage = row['main_image'] as String?;
          final images = _decodeStringList(row['images']);
          final migratedMainImage = mainImage == null
              ? null
              : replacements[mainImage] ?? mainImage;
          final migratedImages = images
              .map((source) => replacements[source] ?? source)
              .toList(growable: false);
          if (migratedMainImage == mainImage &&
              _listEquals(migratedImages, images)) {
            continue;
          }
          await transaction.update(
            'archives',
            {
              'main_image': migratedMainImage,
              'images': migratedImages.isEmpty
                  ? null
                  : jsonEncode(migratedImages),
            },
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
        for (final row in mediaRows) {
          final imagePath = row['image_path']! as String;
          final previewPath = row['preview_path']! as String;
          final migratedImagePath = replacements[imagePath] ?? imagePath;
          final migratedPreviewPath = replacements[previewPath] ?? previewPath;
          if (migratedImagePath == imagePath &&
              migratedPreviewPath == previewPath) {
            continue;
          }
          await transaction.update(
            'media_source_refs',
            {
              'image_path': migratedImagePath,
              'preview_path': migratedPreviewPath,
            },
            where: 'image_id = ? AND source_type = ? AND source_id = ?',
            whereArgs: [row['image_id'], row['source_type'], row['source_id']],
          );
        }
      });
    }

    final managedRoots = _legacyDirectories()
        .map((directory) => p.normalize(p.absolute(directory.path)))
        .toList(growable: false);
    for (final path in migratedLegacyFiles) {
      if (!managedRoots.any((root) => p.isWithin(root, path))) continue;
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // The canonical copy is already committed and will be used next time.
      }
    }
  }

  Future<Map<String, File>> _legacyFilesByName() async {
    final files = <String, File>{};
    for (final directory in _legacyDirectories()) {
      try {
        if (!await directory.exists()) continue;
        await for (final entity in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File) continue;
          final parsed = diaryImageSourceFromFileName(p.basename(entity.path));
          if (parsed != null) files.putIfAbsent(parsed.fileName, () => entity);
        }
      } on FileSystemException {
        // A directly referenced path may still be migrated below.
      }
    }
    return files;
  }

  List<Directory> _legacyDirectories() {
    final documents = _requireDocumentsDirectory();
    final media = p.join(documents.path, 'media');
    return [
      Directory(p.join(media, 'diary')),
      Directory(p.join(media, 'archive')),
      Directory(p.join(media, 'sync')),
      Directory(p.join(media, 'imports')),
    ];
  }

  Directory _requireDocumentsDirectory() {
    final directory = documentsDirectory;
    if (directory == null) {
      throw StateError('DiaryImageStore is not configured.');
    }
    return directory;
  }
}

String? localPathFromImageSource(String source) {
  final normalized = source.trim();
  if (normalized.isEmpty || parseDiaryImageSource(normalized) != null) {
    return null;
  }
  if (RegExp(r'^[A-Za-z]:[\\/]').hasMatch(normalized)) return normalized;
  final uri = Uri.tryParse(normalized);
  if (uri?.scheme == 'file') {
    try {
      return uri!.toFilePath(windows: Platform.isWindows);
    } on Object {
      return null;
    }
  }
  if (uri == null || uri.scheme.isEmpty) return normalized;
  return null;
}

String? _fileNameFromSource(String source) {
  final localPath = localPathFromImageSource(source);
  if (localPath == null) return null;
  return localPath.replaceAll('\\', '/').split('/').last;
}

Iterable<String> _imageSourcesFromHtml(String html) sync* {
  for (final match in _htmlImageSourcePattern.allMatches(html)) {
    final source = match.group(3);
    if (source != null && source.trim().isNotEmpty) yield source;
  }
}

String _rewriteHtmlImageSources(String html, Map<String, String> replacements) {
  return html.replaceAllMapped(_htmlImageSourcePattern, (match) {
    final source = match.group(3)!;
    final replacement = replacements[source];
    if (replacement == null) return match.group(0)!;
    return '${match.group(1)}$replacement${match.group(4)}';
  });
}

List<String> _decodeStringList(Object? value) {
  if (value is! String || value.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(value);
    return decoded is List
        ? decoded.whereType<String>().toList(growable: false)
        : const [];
  } on FormatException {
    return const [];
  }
}

bool _listEquals(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

Future<bool> _filesHaveSameContent(File left, File right) async {
  if (await left.length() != await right.length()) return false;
  final leftBytes = await left.readAsBytes();
  final rightBytes = await right.readAsBytes();
  for (var index = 0; index < leftBytes.length; index++) {
    if (leftBytes[index] != rightBytes[index]) return false;
  }
  return true;
}
