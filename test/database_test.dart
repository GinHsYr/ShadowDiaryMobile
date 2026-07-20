import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/database/app_database.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase appDatabase;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    appDatabase = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });

  tearDown(() => appDatabase.close());

  test('creates the complete version 1 schema', () async {
    final compileOptions = await appDatabase.database.rawQuery(
      'PRAGMA compile_options',
    );
    expect(
      compileOptions.expand((row) => row.values).whereType<String>(),
      contains('ENABLE_FTS5'),
    );

    final rows = await appDatabase.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final tables = rows.map((row) => row['name']).toSet();

    expect(
      tables,
      containsAll({
        'diary_entries',
        'tags',
        'diary_tags',
        'attachments',
        'archives',
        'settings',
        'diary_search_fts',
        'image_refs',
        'person_mention_stats',
        'media_source_refs',
      }),
    );

    final indexRows = await appDatabase.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    );
    final indexes = indexRows.map((row) => row['name']).toSet();
    expect(
      indexes,
      containsAll({
        'idx_entries_created_at',
        'idx_entries_mood',
        'idx_entries_plain_content',
        'idx_diary_tags_tag',
        'idx_attachments_diary',
        'idx_archives_type',
        'idx_archives_name',
        'idx_image_refs_updated_at',
        'idx_person_mention_stats_count',
        'idx_media_source_refs_updated',
        'idx_media_source_refs_source',
        'idx_media_source_refs_image',
      }),
    );

    final triggerRows = await appDatabase.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'trigger'",
    );
    expect(
      triggerRows.map((row) => row['name']),
      containsAll({'diary_entries_ai', 'diary_entries_ad', 'diary_entries_au'}),
    );

    final foreignKeys = await appDatabase.database.rawQuery(
      'PRAGMA foreign_keys',
    );
    expect(foreignKeys.single.values.single, 1);
  });

  test('keeps FTS in sync across insert, update, and delete', () async {
    await _insertEntry(appDatabase, plainContent: 'quiet morning');

    expect(await _search(appDatabase, 'quiet'), hasLength(1));

    await appDatabase.database.update(
      'diary_entries',
      {'plain_content': 'bright evening', 'updated_at': 2},
      where: 'id = ?',
      whereArgs: ['entry-1'],
    );
    expect(await _search(appDatabase, 'quiet'), isEmpty);
    expect(await _search(appDatabase, 'bright'), hasLength(1));

    await appDatabase.database.delete(
      'diary_entries',
      where: 'id = ?',
      whereArgs: ['entry-1'],
    );
    expect(await _search(appDatabase, 'bright'), isEmpty);
  });

  test('cascades diary and archive relationships', () async {
    await _insertEntry(appDatabase);
    final tagId = await appDatabase.database.insert('tags', {'name': 'daily'});
    await appDatabase.database.insert('diary_tags', {
      'diary_id': 'entry-1',
      'tag_id': tagId,
    });
    await appDatabase.database.insert('attachments', {
      'id': 'attachment-1',
      'diary_id': 'entry-1',
      'filename': 'image.png',
      'mime_type': 'image/png',
      'file_path': 'media/image.png',
      'size': 10,
      'created_at': 1,
    });

    await appDatabase.database.delete(
      'diary_entries',
      where: 'id = ?',
      whereArgs: ['entry-1'],
    );
    expect(await appDatabase.database.query('diary_tags'), isEmpty);
    expect(await appDatabase.database.query('attachments'), isEmpty);

    await appDatabase.database.insert('archives', {
      'id': 'archive-1',
      'name': 'Someone',
      'type': 'person',
      'created_at': 1,
      'updated_at': 1,
    });
    await appDatabase.database.insert('person_mention_stats', {
      'archive_id': 'archive-1',
      'mention_count': 2,
      'updated_at': 1,
    });
    await appDatabase.database.delete(
      'archives',
      where: 'id = ?',
      whereArgs: ['archive-1'],
    );
    expect(await appDatabase.database.query('person_mention_stats'), isEmpty);
  });

  test('persists appearance and locale settings', () async {
    final repository = SqliteAppSettingsRepository(appDatabase);
    expect((await repository.load()).themeSeed, ThemeSeed.neutral);

    const expected = AppSettings(
      themeMode: AppThemeMode.dark,
      themeSeed: ThemeSeed.monet,
      localePreference: AppLocalePreference.en,
    );
    await repository.save(expected);

    final restored = await repository.load();
    expect(restored.themeMode, expected.themeMode);
    expect(restored.themeSeed, expected.themeSeed);
    expect(restored.localePreference, expected.localePreference);

    await appDatabase.database.insert('settings', {
      'key': 'appearance.theme_mode',
      'value': 'future-mode',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    expect((await repository.load()).themeMode, AppThemeMode.system);
  });
}

Future<void> _insertEntry(
  AppDatabase database, {
  String plainContent = 'today',
}) {
  return database.database.insert('diary_entries', {
    'id': 'entry-1',
    'title': 'A day',
    'content': '<p>$plainContent</p>',
    'plain_content': plainContent,
    'mood': 'calm',
    'created_at': 1,
    'updated_at': 1,
  });
}

Future<List<Map<String, Object?>>> _search(AppDatabase database, String query) {
  return database.database.rawQuery(
    'SELECT title FROM diary_search_fts WHERE diary_search_fts MATCH ?',
    [query],
  );
}
