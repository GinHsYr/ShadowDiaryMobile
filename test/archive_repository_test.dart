import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/archives/archive.dart';
import 'package:shadow_diary_mobile/core/archives/archive_repository.dart';
import 'package:shadow_diary_mobile/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late SqliteArchiveRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = SqliteArchiveRepository(database);
  });

  tearDown(() => database.close());

  test('creates, reads, updates, and normalizes an archive', () async {
    final createdAt = DateTime.fromMillisecondsSinceEpoch(1000);
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(2000);
    await repository.save(
      Archive(
        id: 'archive-1',
        name: '  张三  ',
        alias: ' 小张， 三哥;老张\n小张 ',
        description: '  同学  ',
        type: ArchiveType.person,
        mainImage: 'main.webp',
        images: const ['one.webp', 'main.webp', 'one.webp', 'two.webp'],
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );

    final archive = await repository.findById('archive-1');
    expect(archive, isNotNull);
    expect(archive!.name, '张三');
    expect(archive.alias, '小张,三哥,老张');
    expect(archive.aliases, ['小张', '三哥', '老张']);
    expect(archive.description, '同学');
    expect(archive.type, ArchiveType.person);
    expect(archive.mainImage, 'main.webp');
    expect(archive.images, ['one.webp', 'two.webp']);
    expect(archive.createdAt, createdAt);
    expect(archive.updatedAt, updatedAt);

    await database.database.insert('person_mention_stats', {
      'archive_id': archive.id,
      'mention_count': 3,
      'updated_at': 2,
    });
    await repository.save(
      Archive(
        id: archive.id,
        name: '张三丰',
        type: ArchiveType.other,
        createdAt: archive.createdAt,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(3000),
      ),
    );

    final updated = await repository.findById(archive.id);
    expect(updated!.name, '张三丰');
    expect(updated.type, ArchiveType.other);
    expect(
      await database.database.query('person_mention_stats'),
      hasLength(1),
      reason: 'updating must not use SQLite REPLACE and trigger cascades',
    );
  });

  test('tolerates malformed image JSON and unknown stored types', () async {
    await database.database.insert('archives', {
      'id': 'future-archive',
      'name': 'Future',
      'type': 'future-type',
      'images': '{not-json',
      'created_at': 1,
      'updated_at': 2,
    });

    final archive = await repository.findById('future-archive');
    expect(archive!.type, ArchiveType.other);
    expect(archive.images, isEmpty);
  });

  test('deletes archives and cascades person mention statistics', () async {
    final now = DateTime.fromMillisecondsSinceEpoch(1);
    await repository.save(
      Archive(
        id: 'archive-1',
        name: 'Someone',
        type: ArchiveType.person,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await database.database.insert('person_mention_stats', {
      'archive_id': 'archive-1',
      'mention_count': 2,
      'updated_at': 1,
    });

    await repository.delete('archive-1');

    expect(await repository.listArchives(), isEmpty);
    expect(await database.database.query('person_mention_stats'), isEmpty);
  });

  test('rejects blank archive names', () async {
    final now = DateTime.fromMillisecondsSinceEpoch(1);
    await expectLater(
      repository.save(
        Archive(
          id: 'blank',
          name: '   ',
          type: ArchiveType.person,
          createdAt: now,
          updatedAt: now,
        ),
      ),
      throwsArgumentError,
    );
  });
}
