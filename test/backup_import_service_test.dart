import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/backup/backup_import_service.dart';
import 'package:shadow_diary_mobile/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

const _backupKey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _imageName = '11111111-1111-4111-8111-111111111111.jpeg';
const _thumbnailName = '11111111-1111-4111-8111-111111111111_thumb.webp';
const _attachmentName = '22222222-2222-4222-8222-222222222222.txt';

void main() {
  setUpAll(sqfliteFfiInit);

  test('uses a SQLite3 Multiple Ciphers bundled build', () {
    final database = sqlite.sqlite3.openInMemory();
    addTearDown(database.close);

    expect(database.select('PRAGMA cipher'), isNotEmpty);
    expect(sqlite.sqlite3.usedCompileOption('ENABLE_FTS5'), isTrue);
  });

  test(
    'previews conflicts and imports only missing dates incrementally',
    () async {
      final harness = await _BackupHarness.create();
      addTearDown(harness.dispose);

      await harness.insertCurrentData();
      final backup = await harness.createBackup(keyFileName: 'backup-key.json');
      final service = harness.serviceFor(backup);

      final preview = await service.selectBackup();

      expect(preview, isNotNull);
      expect(preview!.appVersion, '1.8.2');
      expect(preview.exportedAt, DateTime.utc(2026, 7, 22, 6, 30, 25));
      expect(preview.diaryCount, 2);
      expect(preview.archiveCount, 1);
      expect(preview.attachmentCount, 1);
      expect(preview.mediaFileCount, 2);
      expect(preview.conflictDiaryCount, 1);
      expect(await harness.rowCount('diary_entries'), 2);
      expect(await harness.rowCount('archives'), 1);

      final result = await service.importBackup(
        preview,
        BackupImportMode.incremental,
      );

      expect(result.importedDiaryCount, 1);
      expect(result.importedArchiveCount, 0);
      expect(result.skippedDiaryCount, 1);
      final diaryRows = await harness.database.database.query(
        'diary_entries',
        orderBy: 'created_at',
      );
      expect(diaryRows.map((row) => row['id']), [
        'current-conflict',
        'current-empty',
        'backup-new',
      ]);
      expect(diaryRows.map((row) => row['title']), [
        'Current diary',
        '',
        'Backup new date',
      ]);
      final importedContent = diaryRows.last['content']! as String;
      final imageSource = RegExp(
        r'src="([^"]+)"',
      ).firstMatch(importedContent)!.group(1)!;
      expect(Uri.parse(imageSource).scheme, 'file');
      expect(await File.fromUri(Uri.parse(imageSource)).exists(), isTrue);

      final archiveRows = await harness.database.database.query('archives');
      expect(archiveRows.single['id'], 'current-archive');
      final attachmentRows = await harness.database.database.query(
        'attachments',
      );
      expect(attachmentRows, hasLength(1));
      final attachmentPath = attachmentRows.single['file_path']! as String;
      expect(pIsAbsolute(attachmentPath), isTrue);
      expect(await File(attachmentPath).readAsString(), 'new attachment');
      final tagRows = await harness.database.database.query('tags');
      expect(tagRows.single['name'], 'imported-tag');
      expect(await harness.rowCount('diary_tags'), 1);
    },
  );

  test(
    'overwrite replaces content while preserving current app settings',
    () async {
      final harness = await _BackupHarness.create();
      addTearDown(harness.dispose);

      await harness.insertCurrentData();
      final backup = await harness.createBackup();
      final service = harness.serviceFor(backup);
      final preview = (await service.selectBackup())!;

      final result = await service.importBackup(
        preview,
        BackupImportMode.overwrite,
      );

      expect(result.importedDiaryCount, 2);
      expect(result.importedArchiveCount, 1);
      expect(result.skippedDiaryCount, 0);
      final diaryRows = await harness.database.database.query(
        'diary_entries',
        orderBy: 'created_at',
      );
      expect(diaryRows.map((row) => row['id']), [
        'backup-conflict',
        'backup-new',
      ]);
      final archiveRows = await harness.database.database.query('archives');
      expect(archiveRows.single['id'], 'backup-archive');
      final archiveImagePath = archiveRows.single['main_image']! as String;
      expect(pIsAbsolute(archiveImagePath), isTrue);
      expect(await File(archiveImagePath).exists(), isTrue);
      final archiveImages =
          (jsonDecode(archiveRows.single['images']! as String) as List)
              .cast<String>();
      expect(archiveImages, hasLength(2));
      for (final imagePath in archiveImages) {
        expect(pIsAbsolute(imagePath), isTrue);
        expect(await File(imagePath).exists(), isTrue);
      }
      final settings = await harness.database.database.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['appearance.theme_mode'],
      );
      expect(settings.single['value'], 'dark');
      expect(await harness.rowCount('person_mention_stats'), 1);
      expect(await harness.rowCount('media_source_refs'), 1);
      final mediaSourceRows = await harness.database.database.query(
        'media_source_refs',
      );
      for (final column in ['image_path', 'preview_path']) {
        final uri = Uri.parse(mediaSourceRows.single[column]! as String);
        expect(uri.scheme, 'file');
        expect(await File.fromUri(uri).exists(), isTrue);
      }
      expect(await harness.legacyMediaFile.exists(), isFalse);
      expect(await harness.olderImportDirectory.exists(), isFalse);
      expect(
        await harness.database.database.rawQuery(
          "SELECT title FROM diary_search_fts WHERE diary_search_fts MATCH 'new'",
        ),
        hasLength(1),
      );
    },
  );

  test('rejects unsupported formats before changing local data', () async {
    final harness = await _BackupHarness.create();
    addTearDown(harness.dispose);

    await harness.insertCurrentData();
    final backup = await harness.createBackup(formatVersion: 4);
    final service = harness.serviceFor(backup);

    await expectLater(
      service.selectBackup(),
      throwsA(
        isA<BackupImportException>().having(
          (error) => error.code,
          'code',
          BackupImportErrorCode.unsupportedBackupFormat,
        ),
      ),
    );
    expect(await harness.rowCount('diary_entries'), 2);
    expect(await harness.rowCount('archives'), 1);
  });

  test('rejects unsafe attachment paths', () async {
    final harness = await _BackupHarness.create();
    addTearDown(harness.dispose);

    final backup = await harness.createBackup(
      attachmentPath: 'attachments/../outside.txt',
    );
    final service = harness.serviceFor(backup);

    await expectLater(
      service.selectBackup(),
      throwsA(
        isA<BackupImportException>().having(
          (error) => error.code,
          'code',
          BackupImportErrorCode.invalidBackup,
        ),
      ),
    );
    expect(await harness.rowCount('diary_entries'), 0);
  });

  test('reports a missing key file explicitly', () async {
    final harness = await _BackupHarness.create();
    addTearDown(harness.dispose);

    final backup = await harness.createBackup(includeKeyFile: false);
    final service = harness.serviceFor(backup);

    await expectLater(
      service.selectBackup(),
      throwsA(
        isA<BackupImportException>().having(
          (error) => error.code,
          'code',
          BackupImportErrorCode.missingKeyFile,
        ),
      ),
    );
  });

  test(
    'rolls back overwrite when target constraints reject backup data',
    () async {
      final harness = await _BackupHarness.create();
      addTearDown(harness.dispose);

      await harness.insertCurrentData();
      final backup = await harness.createBackup(invalidImageRef: true);
      final service = harness.serviceFor(backup);
      final preview = (await service.selectBackup())!;

      await expectLater(
        service.importBackup(preview, BackupImportMode.overwrite),
        throwsA(
          isA<BackupImportException>().having(
            (error) => error.code,
            'code',
            BackupImportErrorCode.importFailed,
          ),
        ),
      );
      expect(await harness.rowCount('diary_entries'), 2);
      final archiveRows = await harness.database.database.query('archives');
      expect(archiveRows.single['id'], 'current-archive');
      expect(await harness.legacyMediaFile.exists(), isTrue);
      expect(await harness.olderImportDirectory.exists(), isTrue);
    },
  );
}

bool pIsAbsolute(String path) {
  return File(path).absolute.path == File(path).path;
}

class _BackupHarness {
  _BackupHarness({
    required this.root,
    required this.temporaryDirectory,
    required this.documentsDirectory,
    required this.database,
  });

  final Directory root;
  final Directory temporaryDirectory;
  final Directory documentsDirectory;
  final AppDatabase database;

  File get legacyMediaFile =>
      File('${documentsDirectory.path}/media/diary/legacy.webp');

  Directory get olderImportDirectory =>
      Directory('${documentsDirectory.path}/media/imports/older-import');

  static Future<_BackupHarness> create() async {
    final root = await Directory.systemTemp.createTemp(
      'shadow_diary_backup_import_test_',
    );
    final temporaryDirectory = Directory('${root.path}/temporary')
      ..createSync(recursive: true);
    final documentsDirectory = Directory('${root.path}/documents')
      ..createSync(recursive: true);
    final database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: '${root.path}/current.db',
    );
    return _BackupHarness(
      root: root,
      temporaryDirectory: temporaryDirectory,
      documentsDirectory: documentsDirectory,
      database: database,
    );
  }

  DeviceBackupImportService serviceFor(File backup) {
    return DeviceBackupImportService(
      database,
      pickBackupFile: () async => PickedBackupFile(
        path: backup.path,
        name: 'shadow-diary-backup-20260722-143025.zip',
      ),
      loadTemporaryDirectory: () async => temporaryDirectory,
      loadDocumentsDirectory: () async => documentsDirectory,
    );
  }

  Future<void> insertCurrentData() async {
    final currentDate = DateTime(2026, 7, 20, 8).millisecondsSinceEpoch;
    await database.database.insert('diary_entries', {
      'id': 'current-conflict',
      'title': 'Current diary',
      'content': '<p>keep me</p>',
      'plain_content': 'keep me',
      'mood': 'calm',
      'created_at': currentDate,
      'updated_at': currentDate,
    });
    await database.database.insert('archives', {
      'id': 'current-archive',
      'name': 'Current archive',
      'type': 'person',
      'created_at': currentDate,
      'updated_at': currentDate,
    });
    await database.database.insert('settings', {
      'key': 'appearance.theme_mode',
      'value': 'dark',
    });
    final emptyDate = DateTime(2026, 7, 21, 7).millisecondsSinceEpoch;
    await database.database.insert('diary_entries', {
      'id': 'current-empty',
      'title': '',
      'content': '',
      'plain_content': '',
      'mood': 'calm',
      'created_at': emptyDate,
      'updated_at': emptyDate,
    });
    await legacyMediaFile.create(recursive: true);
    await legacyMediaFile.writeAsBytes([9]);
    await olderImportDirectory.create(recursive: true);
    await File('${olderImportDirectory.path}/old.webp').writeAsBytes([8]);
  }

  Future<File> createBackup({
    int formatVersion = backupFormatVersion,
    String attachmentPath = 'attachments/$_attachmentName',
    bool includeKeyFile = true,
    bool invalidImageRef = false,
    String keyFileName = 'shadow-diary-backup-key.json',
  }) async {
    final sourceDatabasePath =
        '${root.path}/source-${DateTime.now().microsecondsSinceEpoch}.db';
    final sourceDatabase = sqlite.sqlite3.open(sourceDatabasePath);
    _configureCipher(sourceDatabase);
    sourceDatabase.execute('PRAGMA foreign_keys = ON');
    for (final statement in _backupSchema) {
      sourceDatabase.execute(statement);
    }

    final conflictDate = DateTime(2026, 7, 20, 12).millisecondsSinceEpoch;
    final newDate = DateTime(2026, 7, 21, 9).millisecondsSinceEpoch;
    sourceDatabase
        .execute('INSERT INTO diary_entries VALUES (?, ?, ?, ?, ?, ?, ?, ?)', [
          'backup-conflict',
          'Backup conflict',
          '<p>backup conflict</p>',
          'backup conflict',
          'happy',
          null,
          conflictDate,
          conflictDate,
        ]);
    sourceDatabase
        .execute('INSERT INTO diary_entries VALUES (?, ?, ?, ?, ?, ?, ?, ?)', [
          'backup-new',
          'Backup new date',
          '<p>new<img src="diary-image://$_imageName"></p>',
          'new',
          'calm',
          'sunny',
          newDate,
          newDate,
        ]);
    sourceDatabase.execute('INSERT INTO tags(id, name) VALUES (7, ?)', [
      'imported-tag',
    ]);
    sourceDatabase.execute('INSERT INTO diary_tags VALUES (?, 7)', [
      'backup-new',
    ]);
    sourceDatabase
        .execute('INSERT INTO attachments VALUES (?, ?, ?, ?, ?, ?, ?)', [
          '22222222-2222-4222-8222-222222222222',
          'backup-new',
          'note.txt',
          'text/plain',
          attachmentPath,
          14,
          newDate,
        ]);
    sourceDatabase.execute(
      'INSERT INTO archives VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        'backup-archive',
        'Backup archive',
        'Alias',
        'Imported archive',
        'person',
        'diary-image://$_imageName',
        jsonEncode([
          'diary-image://$_imageName',
          'diary-image://$_thumbnailName',
        ]),
        newDate,
        newDate,
      ],
    );
    sourceDatabase.execute('INSERT INTO settings VALUES (?, ?)', [
      'appearance.theme_mode',
      'light',
    ]);
    sourceDatabase.execute('INSERT INTO image_refs VALUES (?, ?, ?)', [
      '11111111-1111-4111-8111-111111111111',
      invalidImageRef ? -1 : 2,
      newDate,
    ]);
    sourceDatabase.execute(
      'INSERT INTO person_mention_stats VALUES (?, ?, ?)',
      ['backup-archive', 3, newDate],
    );
    sourceDatabase.execute(
      'INSERT INTO media_source_refs VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        '11111111-1111-4111-8111-111111111111',
        'diary',
        'backup-new',
        'Backup new date',
        newDate,
        newDate,
        'diary-image://$_imageName',
        'diary-image://$_thumbnailName',
      ],
    );
    sourceDatabase.close();

    final metadata = jsonEncode({
      'appName': 'ShadowDiary',
      'appVersion': '1.8.2',
      'exportedAt': '2026-07-22T06:30:25.000Z',
      'backupFormatVersion': formatVersion,
      'compression': 'zip',
      'encryption': {
        'db': 'sqlcipher',
        'keyFile': 'plain-text',
        'attachments': 'plain-zip',
      },
    });
    final keyFile = jsonEncode({
      'version': 1,
      'format': 'plain-text',
      'dbKeyHex': _backupKey,
    });
    final archive = Archive()
      ..addFile(ArchiveFile.string('metadata.json', metadata));
    if (includeKeyFile) {
      archive.addFile(ArchiveFile.string(keyFileName, keyFile));
    }
    archive
      ..addFile(
        ArchiveFile.bytes(
          'diary.db',
          await File(sourceDatabasePath).readAsBytes(),
        ),
      )
      ..addFile(ArchiveFile.bytes('images/$_imageName', [1, 2, 3, 4]))
      ..addFile(ArchiveFile.bytes('thumbnails/$_thumbnailName', [4, 3, 2, 1]))
      ..addFile(
        ArchiveFile.bytes(
          'attachments/$_attachmentName',
          utf8.encode('new attachment'),
        ),
      );
    final backupFile = File(
      '${root.path}/backup-${DateTime.now().microsecondsSinceEpoch}.zip',
    );
    await backupFile.writeAsBytes(ZipEncoder().encodeBytes(archive));
    return backupFile;
  }

  Future<int> rowCount(String table) async {
    final rows = await database.database.rawQuery(
      'SELECT COUNT(*) AS count FROM $table',
    );
    return rows.single['count']! as int;
  }

  Future<void> dispose() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  }
}

void _configureCipher(sqlite.Database database) {
  database.execute('PRAGMA key = "x\'$_backupKey\'"');
  database.execute('PRAGMA cipher_page_size = 4096');
  database.execute('PRAGMA kdf_iter = 256000');
  database.execute('PRAGMA cipher_hmac_algorithm = HMAC_SHA512');
  database.execute('PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA512');
}

const _backupSchema = <String>[
  '''
    CREATE TABLE diary_entries (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      plain_content TEXT NOT NULL,
      mood TEXT NOT NULL,
      weather TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''',
  'CREATE TABLE tags (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE)',
  '''
    CREATE TABLE diary_tags (
      diary_id TEXT NOT NULL REFERENCES diary_entries(id) ON DELETE CASCADE,
      tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
      PRIMARY KEY (diary_id, tag_id)
    )
  ''',
  '''
    CREATE TABLE attachments (
      id TEXT PRIMARY KEY,
      diary_id TEXT NOT NULL REFERENCES diary_entries(id) ON DELETE CASCADE,
      filename TEXT NOT NULL,
      mime_type TEXT NOT NULL,
      file_path TEXT NOT NULL,
      size INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    )
  ''',
  '''
    CREATE TABLE archives (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      alias TEXT,
      description TEXT,
      type TEXT NOT NULL,
      main_image TEXT,
      images TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''',
  'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
  '''
    CREATE TABLE image_refs (
      image_id TEXT PRIMARY KEY,
      ref_count INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''',
  '''
    CREATE TABLE person_mention_stats (
      archive_id TEXT PRIMARY KEY REFERENCES archives(id) ON DELETE CASCADE,
      mention_count INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''',
  '''
    CREATE TABLE media_source_refs (
      image_id TEXT NOT NULL,
      source_type TEXT NOT NULL,
      source_id TEXT NOT NULL,
      source_title TEXT NOT NULL,
      source_created_at INTEGER NOT NULL,
      source_updated_at INTEGER NOT NULL,
      image_path TEXT NOT NULL,
      preview_path TEXT NOT NULL,
      PRIMARY KEY (image_id, source_type, source_id)
    )
  ''',
];
