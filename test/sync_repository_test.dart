import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/database/app_database.dart';
import 'package:shadow_diary_mobile/core/sync/sync_models.dart';
import 'package:shadow_diary_mobile/core/sync/sync_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late Directory mediaDirectory;
  late SyncRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    mediaDirectory = await Directory.systemTemp.createTemp(
      'shadow-diary-sync-test-',
    );
    repository = SyncRepository(
      database,
      'phone-device',
      loadSyncMediaDirectory: () async => mediaDirectory,
    );
  });

  tearDown(() async {
    await database.close();
    await mediaDirectory.delete(recursive: true);
  });

  test(
    'detects local changes and deletions without repository hooks',
    () async {
      await _insertDiary(database, title: 'First');

      final first = (await repository.prepareSnapshot()).single;
      expect(first.versionVector, {'phone-device': 1});
      expect(first.payload!['calendarDate'], '2026-07-26');
      // Generated with the desktop stableStringify/SHA-256 implementation.
      expect(
        first.contentHash,
        '22b0c49eb9fb0dfa193a14f872fb84fbeacd0f347167ba357177a9b6e6285cbf',
      );

      final unchanged = (await repository.prepareSnapshot()).single;
      expect(unchanged.versionVector, {'phone-device': 1});

      await database.database.update(
        'diary_entries',
        {'title': 'Second', 'updated_at': 2},
        where: 'id = ?',
        whereArgs: ['diary-1'],
      );
      final changed = (await repository.prepareSnapshot()).single;
      expect(changed.versionVector, {'phone-device': 2});
      expect(changed.payload!['title'], 'Second');

      await database.database.delete(
        'diary_entries',
        where: 'id = ?',
        whereArgs: ['diary-1'],
      );
      final deleted = (await repository.prepareSnapshot()).single;
      expect(deleted.isDeleted, isTrue);
      expect(deleted.versionVector, {'phone-device': 3});
    },
  );

  test(
    'applies causally newer records and preserves object archives',
    () async {
      final payload = <String, Object?>{
        'id': 'archive-remote',
        'name': 'Old Camera',
        'aliases': <String>['Camera'],
        'description': 'A synced object',
        'type': 'object',
        'mainImage': null,
        'images': <String>[],
        'createdAt': 10,
        'updatedAt': 20,
      };
      final result = await repository.reconcileRemote([
        SyncRecord(
          entityType: SyncEntityType.archive,
          entityId: 'archive-remote',
          versionVector: const {'desktop-device': 1},
          contentHash: List.filled(64, 'a').join(),
          modifiedAt: 20,
          payload: payload,
        ),
      ], 'desktop-device');

      expect(result.appliedCount, 1);
      final rows = await database.database.query(
        'archives',
        where: 'id = ?',
        whereArgs: ['archive-remote'],
      );
      expect(rows.single['type'], 'object');
      expect(rows.single['alias'], 'Camera');
    },
  );

  test('persists true concurrent edits for explicit resolution', () async {
    await _insertDiary(database, title: 'Phone title');
    await repository.prepareSnapshot();
    final local = (await repository.prepareSnapshot()).single;
    final remotePayload = <String, Object?>{
      ...local.payload!,
      'title': 'Desktop title',
      'updatedAt': 3,
    };
    final result = await repository.reconcileRemote([
      SyncRecord(
        entityType: SyncEntityType.diary,
        entityId: 'diary-1',
        versionVector: const {'desktop-device': 1},
        contentHash: List.filled(64, 'b').join(),
        modifiedAt: 3,
        payload: remotePayload,
      ),
    ], 'desktop-device');

    expect(result.conflicts, hasLength(1));
    expect(result.recordsForPeer.single.payload!['title'], 'Phone title');
    expect(await repository.listConflicts(), hasLength(1));
  });

  test(
    'auto-merges concurrent records that differ only by updatedAt',
    () async {
      await _insertDiary(database, title: 'Same title');
      final local = (await repository.prepareSnapshot()).single;
      final remotePayload = <String, Object?>{
        ...local.payload!,
        'updatedAt': 200,
      };

      final result = await repository.reconcileRemote([
        SyncRecord(
          entityType: SyncEntityType.diary,
          entityId: 'diary-1',
          versionVector: const {'desktop-device': 1},
          contentHash: List.filled(64, 'c').join(),
          modifiedAt: 200,
          payload: remotePayload,
        ),
      ], 'desktop-device');

      expect(result.conflicts, isEmpty);
      expect(result.appliedCount, 1);
      expect(result.recordsForPeer.single.versionVector, {
        'phone-device': 1,
        'desktop-device': 1,
      });
      expect(await repository.listConflicts(), isEmpty);
      final row = (await database.database.query(
        'diary_entries',
        where: 'id = ?',
        whereArgs: ['diary-1'],
      )).single;
      expect(row['updated_at'], 200);
      expect(row['title'], 'Same title');
    },
  );

  test('ignores missing versus empty archive media fields', () async {
    await _insertArchive(database);
    final local = (await repository.prepareSnapshot()).single;
    final remotePayload = Map<String, Object?>.of(local.payload!)
      ..remove('mainImage')
      ..remove('images');

    final result = await repository.reconcileRemote([
      SyncRecord(
        entityType: SyncEntityType.archive,
        entityId: 'archive-1',
        versionVector: const {'desktop-device': 1},
        contentHash: List.filled(64, 'd').join(),
        modifiedAt: 1,
        payload: remotePayload,
      ),
    ], 'desktop-device');

    expect(result.conflicts, isEmpty);
    expect(result.recordsForPeer.single.payload!['mainImage'], isNull);
    expect(result.recordsForPeer.single.payload!['images'], isEmpty);
    expect(await repository.listConflicts(), isEmpty);
  });

  test(
    'normalizes equivalent archive image locations before comparing',
    () async {
      const mainImageId = '123e4567-e89b-12d3-a456-426614174000.webp';
      const galleryImageId = '223e4567-e89b-42d3-a456-426614174001.jpg';
      await _insertArchive(
        database,
        mainImage: '/data/user/0/app/media/$mainImageId',
        images: const ['/data/user/0/app/media/$galleryImageId'],
      );
      final local = (await repository.prepareSnapshot()).single;
      expect(local.payload!['mainImage'], 'diary-image://$mainImageId');
      expect(local.payload!['images'], ['diary-image://$galleryImageId']);

      final remotePayload = <String, Object?>{
        ...local.payload!,
        'mainImage': 'file:///C:/ShadowDiary/images/$mainImageId',
        'images': <String>['C:\\ShadowDiary\\images\\$galleryImageId'],
        'updatedAt': 200,
      };
      final result = await repository.reconcileRemote([
        SyncRecord(
          entityType: SyncEntityType.archive,
          entityId: 'archive-1',
          versionVector: const {'desktop-device': 1},
          contentHash: List.filled(64, 'e').join(),
          modifiedAt: 200,
          payload: remotePayload,
        ),
      ], 'desktop-device');

      expect(result.conflicts, isEmpty);
      expect(result.appliedCount, 1);
      final snapshot = (await repository.prepareSnapshot()).single;
      expect(snapshot.payload!['mainImage'], 'diary-image://$mainImageId');
      expect(snapshot.payload!['images'], ['diary-image://$galleryImageId']);
      expect(snapshot.versionVector, {'phone-device': 1, 'desktop-device': 1});
    },
  );

  test('keeps genuinely different archive images as a conflict', () async {
    const localImageId = '123e4567-e89b-12d3-a456-426614174000.webp';
    const remoteImageId = '323e4567-e89b-42d3-b456-426614174002.webp';
    await _insertArchive(
      database,
      mainImage: '/data/user/0/app/media/$localImageId',
    );
    final local = (await repository.prepareSnapshot()).single;
    final remotePayload = <String, Object?>{
      ...local.payload!,
      'mainImage': 'diary-image://$remoteImageId',
    };

    final result = await repository.reconcileRemote([
      SyncRecord(
        entityType: SyncEntityType.archive,
        entityId: 'archive-1',
        versionVector: const {'desktop-device': 1},
        contentHash: List.filled(64, 'f').join(),
        modifiedAt: 1,
        payload: remotePayload,
      ),
    ], 'desktop-device');

    expect(result.conflicts, hasLength(1));
    expect(await repository.listConflicts(), hasLength(1));
  });

  test('keeping both conflict sides creates a converged diary copy', () async {
    await _insertDiary(database, title: 'Phone title');
    final local = (await repository.prepareSnapshot()).single;
    final remotePayload = <String, Object?>{
      ...local.payload!,
      'title': 'Desktop title',
      'updatedAt': 3,
    };
    await repository.reconcileRemote([
      SyncRecord(
        entityType: SyncEntityType.diary,
        entityId: 'diary-1',
        versionVector: const {'desktop-device': 1},
        contentHash: List.filled(64, 'b').join(),
        modifiedAt: 3,
        payload: remotePayload,
      ),
    ], 'desktop-device');
    final conflict = (await repository.listConflicts()).single;

    await repository.resolveConflict(conflict, SyncConflictChoice.keepBoth);

    expect(await repository.listConflicts(), isEmpty);
    final rows = await database.database.query(
      'diary_entries',
      orderBy: 'title',
    );
    expect(rows, hasLength(2));
    expect(
      rows.map((row) => row['title']),
      containsAll(['Phone title', 'Desktop title (冲突副本)']),
    );
    final snapshot = await repository.prepareSnapshot();
    final copy = snapshot.singleWhere((record) => record.entityId != 'diary-1');
    expect(copy.versionVector, {'phone-device': 1});
    expect(copy.payload, isNot(contains('name')));
    expect(
      (await repository.prepareSnapshot())
          .singleWhere((record) => record.entityId == copy.entityId)
          .versionVector,
      copy.versionVector,
    );
  });

  test(
    'accepts synchronized thumbnail assets used by desktop avatars',
    () async {
      const id = '123e4567-e89b-12d3-a456-426614174000_thumb.webp';
      const bytes = <int>[97, 98, 99];
      const hash =
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

      await repository.storeAsset(id, bytes, hash);

      expect(await repository.hasAsset(id, hash), isTrue);
      expect(
        await File(
          '${mediaDirectory.path}${Platform.pathSeparator}$id',
        ).readAsBytes(),
        bytes,
      );
    },
  );

  test('accepts synchronized legacy JPEG assets', () async {
    const id = '223e4567-e89b-42d3-a456-426614174001.jpg';
    const bytes = <int>[97, 98, 99];
    const hash =
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

    await repository.storeAsset(id, bytes, hash);

    expect(await repository.hasAsset(id, hash), isTrue);
    expect(
      await File(
        '${mediaDirectory.path}${Platform.pathSeparator}$id',
      ).readAsBytes(),
      bytes,
    );
  });

  test('does not overwrite an immutable asset identifier', () async {
    const id = '123e4567-e89b-42d3-a456-426614174000.webp';
    const original = <int>[97, 98, 99];
    const originalHash =
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
    const replacementHash =
        'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb';

    await repository.storeAsset(id, original, originalHash);

    await expectLater(
      repository.storeAsset(id, const [97], replacementHash),
      throwsFormatException,
    );
    expect(
      await File(
        '${mediaDirectory.path}${Platform.pathSeparator}$id',
      ).readAsBytes(),
      original,
    );
  });

  test('collects legacy JPEG archive assets with their MIME type', () async {
    const id = '223e4567-e89b-42d3-a456-426614174001.jpg';
    final image = File('${mediaDirectory.path}${Platform.pathSeparator}$id');
    await image.writeAsBytes(const [97, 98, 99]);
    await _insertArchive(database, images: [image.path]);

    final assets = await repository.collectAssets(
      await repository.prepareSnapshot(),
    );

    expect(assets, hasLength(1));
    expect(assets.single.id, id);
    expect(assets.single.mimeType, 'image/jpeg');
  });
}

Future<void> _insertDiary(AppDatabase database, {required String title}) async {
  await database.database.insert('diary_entries', {
    'id': 'diary-1',
    'title': title,
    'content': '<p>Quiet day</p>',
    'plain_content': 'Quiet day',
    'mood': 'calm',
    'created_at': DateTime(2026, 7, 26).millisecondsSinceEpoch,
    'updated_at': 1,
  });
}

Future<void> _insertArchive(
  AppDatabase database, {
  String? mainImage,
  List<String> images = const [],
}) async {
  await database.database.insert('archives', {
    'id': 'archive-1',
    'name': 'Camera',
    'type': 'object',
    'main_image': mainImage,
    'images': jsonEncode(images),
    'created_at': 1,
    'updated_at': 1,
  });
}
