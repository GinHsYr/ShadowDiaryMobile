import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shadow_diary_mobile/core/backup/backup_export_service.dart';
import 'package:shadow_diary_mobile/core/database/app_database.dart';
import 'package:shadow_diary_mobile/core/services/diary_image_store.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('exports a desktop-compatible v5 zip backup', () async {
    final root = await Directory.systemTemp.createTemp(
      'shadow_diary_export_test_',
    );
    final database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: p.join(root.path, 'current.db'),
    );
    final documents = Directory(p.join(root.path, 'documents'));
    final imageStore = DiaryImageStore(documents);
    await imageStore.ensureDirectories();
    final imageName = '11111111-1111-4111-8111-111111111111.webp';
    final thumbnailName = '11111111-1111-4111-8111-111111111111_thumb.webp';
    await File(
      p.join(imageStore.imageDirectory.path, imageName),
    ).writeAsBytes([1, 2]);
    await File(
      p.join(imageStore.thumbnailDirectory.path, thumbnailName),
    ).writeAsBytes([3, 4]);
    final attachmentName = '22222222-2222-4222-8222-222222222222.txt';
    final attachment = File(
      p.join(documents.path, 'attachments', attachmentName),
    );
    await attachment.create(recursive: true);
    await attachment.writeAsString('attachment');
    await database.database.insert('diary_entries', {
      'id': 'entry-1',
      'title': 'Export me',
      'content': '<p>Hello</p>',
      'plain_content': 'Hello',
      'mood': 'calm',
      'weather': null,
      'created_at': 1000,
      'updated_at': 1000,
    });
    await database.database.insert('attachments', {
      'id': '22222222-2222-4222-8222-222222222222',
      'diary_id': 'entry-1',
      'filename': attachmentName,
      'mime_type': 'text/plain',
      'file_path': 'attachments/$attachmentName',
      'size': 10,
      'created_at': 1000,
    });
    await database.database.insert('settings', {
      'key': 'security.app_lock_enabled',
      'value': 'true',
    });

    final outputPath = p.join(root.path, 'backup');
    final service = DeviceBackupExportService(
      database,
      imageStore: imageStore,
      appVersion: 'test-version',
      random: _FixedRandom(),
      saveBackupFile: (fileName, source) async {
        expect(await source.exists(), isTrue);
        await source.copy('$outputPath.zip');
        return '$outputPath.zip';
      },
    );

    try {
      final result = await service.exportBackup();
      expect(result?.path, '$outputPath.zip');
      final archive = ZipDecoder().decodeBytes(
        await File(result!.path).readAsBytes(),
      );
      final files = {
        for (final file in archive.where((file) => file.isFile)) file.name,
      };
      expect(
        files,
        containsAll([
          'diary.db',
          'metadata.json',
          'backup-key.json',
          'images/$imageName',
          'thumbnails/$thumbnailName',
          'attachments/$attachmentName',
        ]),
      );

      final metadata =
          jsonDecode(
                utf8.decode(archive.findFile('metadata.json')!.readBytes()!),
              )
              as Map<String, dynamic>;
      expect(metadata['backupFormatVersion'], backupExportFormatVersion);
      expect(metadata['appVersion'], 'test-version');
      expect(metadata['encryption']['db'], 'sqlcipher');
      final key =
          jsonDecode(
                utf8.decode(archive.findFile('backup-key.json')!.readBytes()!),
              )
              as Map<String, dynamic>;
      final keyHex = key['dbKeyHex'] as String;
      expect(keyHex, matches(RegExp(r'^[0-9a-f]{64}$')));

      final extractedDatabase = File(p.join(root.path, 'exported.db'));
      await extractedDatabase.writeAsBytes(
        archive.findFile('diary.db')!.readBytes()!,
      );
      final encrypted = sqlite.sqlite3.open(
        extractedDatabase.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        _configureCipher(encrypted, keyHex);
        expect(
          encrypted.select('SELECT title FROM diary_entries').single['title'],
          'Export me',
        );
        expect(
          encrypted.select(
            "SELECT key FROM settings WHERE key = 'security.app_lock_enabled'",
          ),
          isEmpty,
        );
      } finally {
        encrypted.close();
      }
    } finally {
      await database.close();
      await root.delete(recursive: true);
    }
  });

  test('returns null when the save picker is canceled', () async {
    final root = await Directory.systemTemp.createTemp(
      'shadow_diary_export_cancel_',
    );
    final database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: p.join(root.path, 'current.db'),
    );
    final service = DeviceBackupExportService(
      database,
      imageStore: DiaryImageStore(Directory(p.join(root.path, 'documents'))),
      saveBackupFile: (fileName, source) async => null,
    );
    try {
      expect(await service.exportBackup(), isNull);
    } finally {
      await database.close();
      await root.delete(recursive: true);
    }
  });
}

class _FixedRandom implements Random {
  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0.5;

  @override
  int nextInt(int max) => 171;
}

void _configureCipher(sqlite.Database database, String keyHex) {
  database.execute('PRAGMA key = "x\'$keyHex\'"');
  database.execute('PRAGMA cipher_page_size = 4096');
  database.execute('PRAGMA kdf_iter = 256000');
  database.execute('PRAGMA cipher_hmac_algorithm = HMAC_SHA512');
  database.execute('PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA512');
}
