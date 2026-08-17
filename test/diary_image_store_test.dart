import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shadow_diary_mobile/core/database/app_database.dart';
import 'package:shadow_diary_mobile/core/services/diary_image_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _imageId = '123e4567-e89b-42d3-a456-426614174000';
const _archiveImageId = '223e4567-e89b-42d3-a456-426614174001';
const _missingImageId = '323e4567-e89b-42d3-a456-426614174002';

void main() {
  setUpAll(sqfliteFfiInit);

  group('diary image protocol', () {
    test('normalizes valid desktop-compatible image sources', () {
      final image = parseDiaryImageSource(
        '  DIARY-IMAGE://${_imageId.toUpperCase()}.JPEG  ',
      );
      final unsafeImage = parseDiaryImageSource(
        'unsafe:DIARY-IMAGE://${_imageId.toUpperCase()}.PNG',
      );
      final duplicatedSchemeImage = parseDiaryImageSource(
        'diary-imagDIARY-IMAGE://${_imageId.toUpperCase()}.WEBP',
      );
      final thumbnail = parseDiaryImageSource(
        'diary-image://${_imageId}_thumb.webp',
      );

      expect(image, isNotNull);
      expect(image!.imageId, _imageId);
      expect(image.extension, 'jpeg');
      expect(image.isThumbnail, isFalse);
      expect(image.source, 'diary-image://$_imageId.jpeg');
      expect(unsafeImage, isNotNull);
      expect(unsafeImage!.source, 'diary-image://$_imageId.png');
      expect(duplicatedSchemeImage, isNotNull);
      expect(duplicatedSchemeImage!.source, 'diary-image://$_imageId.webp');
      expect(thumbnail, isNotNull);
      expect(thumbnail!.isThumbnail, isTrue);
      expect(thumbnail.fileName, '${_imageId}_thumb.webp');
    });

    test('rejects malformed and path-traversing sources', () {
      expect(
        parseDiaryImageSource('diary-image://$_imageId.webp/other.webp'),
        isNull,
      );
      expect(
        parseDiaryImageSource('diary-image://$_imageId.webp?size=small'),
        isNull,
      );
      expect(parseDiaryImageSource('diary-image://../$_imageId.webp'), isNull);
      expect(
        parseDiaryImageSource(
          'diary-image://123e4567-e89b-02d3-a456-426614174000.webp',
        ),
        isNull,
      );
      expect(parseDiaryImageSource('file:///tmp/$_imageId.webp'), isNull);
    });

    test('maps original images and thumbnails to separate directories', () {
      final documents = Directory(p.join('root', 'documents'));
      final store = DiaryImageStore(documents);

      expect(
        store.fileForSource('diary-image://$_imageId.webp')!.path,
        p.join(documents.path, 'images', '$_imageId.webp'),
      );
      expect(
        store.fileForSource('diary-image://${_imageId}_thumb.webp')!.path,
        p.join(documents.path, 'thumbnails', '${_imageId}_thumb.webp'),
      );
      expect(
        store.fileForSource('unsafe:diary-image://$_imageId.webp')!.path,
        p.join(documents.path, 'images', '$_imageId.webp'),
      );
    });

    test('canonicalizes only image attributes without moving their tags', () {
      const secondId = '223e4567-e89b-42d3-a456-426614174001';
      const remoteHtml =
          '<p>Before</p>'
          '<p><img alt="first" '
          'src="file:///C:/Shadow%20Diary/images/$_imageId.webp" '
          'style="width:50%"></p>'
          '<p>Between $_imageId.webp</p>'
          "<p><img data-src='/data/user/0/app/images/$secondId.PNG'></p>"
          '<a href="file:///C:/ShadowDiary/images/$_imageId.webp">After</a>';

      final canonical = canonicalizeDiaryImageSourcesInHtml(remoteHtml);

      expect(
        canonical,
        '<p>Before</p>'
        '<p><img alt="first" src="diary-image://$_imageId.webp" '
        'style="width:50%"></p>'
        '<p>Between $_imageId.webp</p>'
        "<p><img data-src='diary-image://$secondId.png'></p>"
        '<a href="file:///C:/ShadowDiary/images/$_imageId.webp">After</a>',
      );
      expect(diaryImageSourcesFromHtml(canonical), [
        'diary-image://$_imageId.webp',
        'diary-image://$secondId.png',
      ]);
      expect(canonicalizeDiaryImageSourcesInHtml(canonical), canonical);

      final unsafeHtml = '<img src="unsafe:diary-image://$_imageId.webp">';
      expect(
        canonicalizeDiaryImageSourcesInHtml(unsafeHtml),
        '<img src="diary-image://$_imageId.webp">',
      );

      final duplicatedSchemeHtml =
          '<img src="diary-imagdiary-image://$_imageId.webp">';
      expect(
        canonicalizeDiaryImageSourcesInHtml(duplicatedSchemeHtml),
        '<img src="diary-image://$_imageId.webp">',
      );
    });

    test('leaves remote URLs and malformed local sources unchanged', () {
      const html =
          '<img src="https://example.com/photo.webp">'
          '<img src="file:///tmp/not-a-managed-name.webp?size=small">'
          '<img aria-src="C:\\images\\$_imageId.webp">';

      expect(canonicalizeDiaryImageSourcesInHtml(html), html);
    });
  });

  test('migrates managed files and all persisted image references', () async {
    final root = await Directory.systemTemp.createTemp(
      'shadow-diary-image-migration-',
    );
    final documents = Directory(p.join(root.path, 'documents'))
      ..createSync(recursive: true);
    final database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: p.join(root.path, 'migration.db'),
    );
    addTearDown(() async {
      await database.close();
      if (await root.exists()) await root.delete(recursive: true);
    });

    final diaryFile = File(
      p.join(documents.path, 'media', 'diary', '$_imageId.webp'),
    );
    final archiveFile = File(
      p.join(documents.path, 'media', 'archive', '$_archiveImageId.jpeg'),
    );
    final thumbnailFile = File(
      p.join(
        documents.path,
        'media',
        'imports',
        'session',
        'thumbnails',
        '${_archiveImageId}_thumb.webp',
      ),
    );
    for (final file in [diaryFile, archiveFile, thumbnailFile]) {
      file.parent.createSync(recursive: true);
    }
    final largeImageBytes = List<int>.generate(
      3 * 64 * 1024 + 17,
      (index) => index % 251,
      growable: false,
    );
    diaryFile.writeAsBytesSync(largeImageBytes);
    archiveFile.writeAsBytesSync([1, 2, 3]);
    thumbnailFile.writeAsBytesSync([1, 2, 3]);
    final missingPath = p.join(
      documents.path,
      'media',
      'diary',
      '$_missingImageId.webp',
    );
    final diaryUri = Uri.file(diaryFile.path).toString();

    await database.database.insert('diary_entries', {
      'id': 'diary-1',
      'title': 'Images',
      'content':
          '<p><img src="$diaryUri"></p>'
          '<p><img data-src="$missingPath"></p>',
      'plain_content': '',
      'mood': 'calm',
      'created_at': 1,
      'updated_at': 2,
    });
    await database.database.insert('archives', {
      'id': 'archive-1',
      'name': 'Archive',
      'type': 'person',
      'main_image': archiveFile.path,
      'images': jsonEncode([
        Uri.file(thumbnailFile.path).toString(),
        missingPath,
      ]),
      'created_at': 1,
      'updated_at': 2,
    });
    await database.database.insert('media_source_refs', {
      'image_id': _archiveImageId,
      'source_type': 'archive',
      'source_id': 'archive-1',
      'source_title': 'Archive',
      'source_created_at': 1,
      'source_updated_at': 2,
      'image_path': archiveFile.path,
      'preview_path': Uri.file(thumbnailFile.path).toString(),
    });

    final store = DiaryImageStore(documents);
    await store.migrateLegacyReferences(database);

    final marker = await database.database.query(
      'settings',
      where: 'key = ?',
      whereArgs: [diaryImageMigrationSettingKey],
    );
    expect(marker.single['value'], '1');

    final lateLegacyFile = File(missingPath)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync([9, 8, 7]);
    await store.migrateLegacyReferences(database);

    final diary = (await database.database.query('diary_entries')).single;
    expect(diary['content'], contains('diary-image://$_imageId.webp'));
    expect(diary['content'], contains(missingPath));
    expect(diary['updated_at'], 2);

    final archive = (await database.database.query('archives')).single;
    expect(archive['main_image'], 'diary-image://$_archiveImageId.jpeg');
    expect(jsonDecode(archive['images']! as String), [
      'diary-image://${_archiveImageId}_thumb.webp',
      missingPath,
    ]);

    final media = (await database.database.query('media_source_refs')).single;
    expect(media['image_path'], 'diary-image://$_archiveImageId.jpeg');
    expect(
      media['preview_path'],
      'diary-image://${_archiveImageId}_thumb.webp',
    );

    expect(
      await File(p.join(documents.path, 'images', '$_imageId.webp')).exists(),
      isTrue,
    );
    expect(
      await File(
        p.join(documents.path, 'images', '$_archiveImageId.jpeg'),
      ).exists(),
      isTrue,
    );
    expect(
      await File(
        p.join(documents.path, 'thumbnails', '${_archiveImageId}_thumb.webp'),
      ).exists(),
      isTrue,
    );
    expect(await diaryFile.exists(), isFalse);
    expect(await archiveFile.exists(), isFalse);
    expect(await thumbnailFile.exists(), isFalse);
    expect(await lateLegacyFile.exists(), isTrue);
    expect(
      await File(
        p.join(documents.path, 'images', '$_missingImageId.webp'),
      ).exists(),
      isFalse,
    );
  });

  test(
    'cleans an original and thumbnail only after all references are gone',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'shadow-diary-image-cleanup-',
      );
      final documents = Directory(p.join(root.path, 'documents'))
        ..createSync(recursive: true);
      final database = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: p.join(root.path, 'cleanup.db'),
      );
      addTearDown(() async {
        await database.close();
        if (await root.exists()) await root.delete(recursive: true);
      });

      final store = DiaryImageStore(documents);
      await store.ensureDirectories();
      final original = File(p.join(store.imageDirectory.path, '$_imageId.webp'))
        ..writeAsBytesSync([1]);
      final thumbnail = File(
        p.join(store.thumbnailDirectory.path, '${_imageId}_thumb.webp'),
      )..writeAsBytesSync([2]);
      final orphan = File(
        p.join(store.imageDirectory.path, '$_archiveImageId.webp'),
      )..writeAsBytesSync([3]);

      await database.database.insert('diary_entries', {
        'id': 'diary-cleanup',
        'title': 'Keep image',
        'content': '<img src="diary-image://$_imageId.webp">',
        'plain_content': '',
        'mood': 'calm',
        'created_at': 1,
        'updated_at': 1,
      });

      await store.cleanupUnreferenced(database);

      expect(await original.exists(), isTrue);
      expect(await thumbnail.exists(), isTrue);
      expect(await orphan.exists(), isFalse);

      await database.database.delete(
        'diary_entries',
        where: 'id = ?',
        whereArgs: ['diary-cleanup'],
      );
      await database.database.insert('sync_conflicts', {
        'id': 'conflict-1',
        'entity_type': 'diary',
        'entity_id': 'diary-cleanup',
        'peer_device_id': 'desktop',
        'local_payload': jsonEncode({
          'content': '<img src="diary-image://$_imageId.webp">',
        }),
        'remote_payload': null,
        'local_vector': '{}',
        'remote_vector': '{}',
        'created_at': 1,
      });
      await store.cleanupUnreferenced(database, candidates: [original.path]);
      expect(await original.exists(), isTrue);
      expect(await thumbnail.exists(), isTrue);

      await database.database.delete('sync_conflicts');
      await store.cleanupUnreferenced(database, candidates: [original.path]);
      expect(await original.exists(), isFalse);
      expect(await thumbnail.exists(), isFalse);
    },
  );
}
