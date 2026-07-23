import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/database/app_database.dart';
import 'package:shadow_diary_mobile/core/diary/diary_entry.dart';
import 'package:shadow_diary_mobile/core/diary/diary_repository.dart';
import 'package:shadow_diary_mobile/core/diary/diary_search.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late SqliteDiaryRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = SqliteDiaryRepository(database);
  });

  tearDown(() => database.close());

  test(
    'combines keyword groups with archive aliases and newest-first order',
    () async {
      await _insertArchive(
        database,
        id: 'xiaoming',
        name: '小明',
        alias: '明明;阿明',
      );
      await repository.save(_entry('newest', '生日散步', '今天和明明去了公园', 300));
      await repository.save(_entry('older', '朋友生日', '阿明带来了蛋糕', 200));
      await repository.save(_entry('missing-person', '生日', '只有蛋糕', 400));

      final result = await repository.searchDiaries(
        const DiarySearchParams(keyword: '生日 小明'),
      );

      expect(result.entries.map((entry) => entry.id), ['newest', 'older']);
      expect(result.total, 2);
      expect(
        result.expandedKeywords,
        containsAll(<String>['生日', '小明', '明明', '阿明']),
      );
    },
  );

  test(
    'applies Unicode standalone boundaries to one-character aliases',
    () async {
      await _insertArchive(database, id: 'alice', name: 'Alice', alias: 'A');
      await repository.save(_entry('standalone', 'Met A today', 'Hello', 300));
      await repository.save(_entry('full-name', 'Alice visited', 'Hello', 200));
      await repository.save(_entry('embedded', 'Apple picking', 'Hello', 400));

      final result = await repository.searchDiaries(
        const DiarySearchParams(keyword: 'A'),
      );

      expect(result.entries.map((entry) => entry.id), [
        'standalone',
        'full-name',
      ]);
      expect(
        result.highlightKeywords,
        contains(
          isA<SearchHighlightKeyword>()
              .having((keyword) => keyword.value, 'value', 'A')
              .having((keyword) => keyword.standalone, 'standalone', isTrue),
        ),
      );
    },
  );

  test('combines mood, inclusive date range, and AND tag filters', () async {
    final july10 = DateTime(2026, 7, 10, 18);
    final july11 = DateTime(2026, 7, 11, 9);
    await repository.save(
      _entryAt('match', 'Quiet day', 'A calm afternoon', july10, mood: 'calm'),
    );
    await repository.save(
      _entryAt(
        'wrong-mood',
        'Quiet day',
        'Still searchable',
        july10,
        mood: 'sad',
      ),
    );
    await repository.save(
      _entryAt(
        'wrong-date',
        'Quiet day',
        'Still searchable',
        july11,
        mood: 'calm',
      ),
    );
    final dailyTag = await database.database.insert('tags', {'name': 'daily'});
    final quietTag = await database.database.insert('tags', {'name': 'quiet'});
    for (final tagId in [dailyTag, quietTag]) {
      await database.database.insert('diary_tags', {
        'diary_id': 'match',
        'tag_id': tagId,
      });
    }
    await database.database.insert('diary_tags', {
      'diary_id': 'wrong-mood',
      'tag_id': dailyTag,
    });

    final result = await repository.searchDiaries(
      DiarySearchParams(
        keyword: 'quiet',
        mood: 'calm',
        tags: const ['daily', 'quiet'],
        dateFrom: DateTime(2026, 7, 10),
        dateTo: DateTime(2026, 7, 10),
      ),
    );

    expect(result.entries.single.id, 'match');
    expect(result.total, 1);
  });

  test(
    'treats LIKE wildcards and symbol-only queries as literal text',
    () async {
      await repository.save(
        _entry('symbols', '100% ready', 'A _ marker and 🎉', 200),
      );
      await repository.save(
        _entry('plain', '1000 ready', 'A normal marker', 300),
      );

      for (final query in ['%', '_', '🎉']) {
        final result = await repository.searchDiaries(
          DiarySearchParams(keyword: query),
        );
        expect(result.entries.map((entry) => entry.id), ['symbols']);
      }
    },
  );

  test('persists at most ten deduplicated recent searches', () async {
    for (var index = 0; index < 12; index++) {
      await repository.rememberSearch('query $index');
    }
    await repository.rememberSearch('QUERY 5');

    final history = await repository.loadSearchHistory();
    expect(history, hasLength(10));
    expect(history.first, 'QUERY 5');
    expect(
      history.where((query) => query.toLowerCase() == 'query 5'),
      hasLength(1),
    );

    await repository.clearSearchHistory();
    expect(await repository.loadSearchHistory(), isEmpty);
  });
}

Future<void> _insertArchive(
  AppDatabase database, {
  required String id,
  required String name,
  String? alias,
}) {
  return database.database.insert('archives', {
    'id': id,
    'name': name,
    'alias': alias,
    'type': 'person',
    'created_at': 1,
    'updated_at': 1,
  });
}

DiaryEntry _entry(
  String id,
  String title,
  String plainContent,
  int milliseconds,
) {
  return _entryAt(
    id,
    title,
    plainContent,
    DateTime.fromMillisecondsSinceEpoch(milliseconds),
  );
}

DiaryEntry _entryAt(
  String id,
  String title,
  String plainContent,
  DateTime createdAt, {
  String mood = 'happy',
}) {
  return DiaryEntry(
    id: id,
    title: title,
    content: '<p>$plainContent</p>',
    plainContent: plainContent,
    mood: mood,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}
