import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._(this.database);

  static const databaseName = 'shadow_diary.db';
  static const schemaVersion = 1;

  final Database database;

  /// Opens the app database with a bundled SQLite build.
  ///
  /// Android's platform SQLite does not consistently include FTS5, while the
  /// bundled build does. Keeping the normal sqflite database directory makes
  /// the file location stable if the backend changes.
  static Future<AppDatabase> openBundled() async {
    final databaseDirectory = await getDatabasesPath();
    await Directory(databaseDirectory).create(recursive: true);
    sqfliteFfiInit();
    return open(
      factory: databaseFactoryFfi,
      path: p.join(databaseDirectory, databaseName),
    );
  }

  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final selectedFactory = factory ?? databaseFactory;
    final databasePath =
        path ?? p.join(await selectedFactory.getDatabasesPath(), databaseName);
    final database = await selectedFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.setJournalMode('WAL');
        },
        onCreate: (db, version) => _createSchema(db),
        onUpgrade: _migrate,
      ),
    );
    return AppDatabase._(database);
  }

  Future<void> close() => database.close();

  static Future<void> _migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 1) {
      await _createSchema(db);
    }
  }

  static Future<void> _createSchema(Database db) async {
    for (final statement in _schemaStatements) {
      await db.execute(statement);
    }
  }

  static const List<String> _schemaStatements = [
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
    'CREATE INDEX idx_entries_created_at ON diary_entries(created_at)',
    'CREATE INDEX idx_entries_mood ON diary_entries(mood)',
    'CREATE INDEX idx_entries_plain_content ON diary_entries(plain_content)',
    '''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''',
    '''
      CREATE TABLE diary_tags (
        diary_id TEXT NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (diary_id, tag_id),
        FOREIGN KEY (diary_id) REFERENCES diary_entries(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''',
    'CREATE INDEX idx_diary_tags_tag ON diary_tags(tag_id)',
    '''
      CREATE TABLE attachments (
        id TEXT PRIMARY KEY,
        diary_id TEXT NOT NULL,
        filename TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        file_path TEXT NOT NULL,
        size INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (diary_id) REFERENCES diary_entries(id) ON DELETE CASCADE
      )
    ''',
    'CREATE INDEX idx_attachments_diary ON attachments(diary_id)',
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
    'CREATE INDEX idx_archives_type ON archives(type)',
    'CREATE INDEX idx_archives_name ON archives(name)',
    '''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''',
    '''
      CREATE VIRTUAL TABLE diary_search_fts USING fts5(
        title,
        plain_content,
        content='diary_entries',
        content_rowid='rowid',
        tokenize='unicode61'
      )
    ''',
    '''
      CREATE TRIGGER diary_entries_ai AFTER INSERT ON diary_entries BEGIN
        INSERT INTO diary_search_fts(rowid, title, plain_content)
        VALUES (new.rowid, new.title, new.plain_content);
      END
    ''',
    '''
      CREATE TRIGGER diary_entries_ad AFTER DELETE ON diary_entries BEGIN
        INSERT INTO diary_search_fts(
          diary_search_fts,
          rowid,
          title,
          plain_content
        ) VALUES ('delete', old.rowid, old.title, old.plain_content);
      END
    ''',
    '''
      CREATE TRIGGER diary_entries_au AFTER UPDATE ON diary_entries BEGIN
        INSERT INTO diary_search_fts(
          diary_search_fts,
          rowid,
          title,
          plain_content
        ) VALUES ('delete', old.rowid, old.title, old.plain_content);
        INSERT INTO diary_search_fts(rowid, title, plain_content)
        VALUES (new.rowid, new.title, new.plain_content);
      END
    ''',
    '''
      CREATE TABLE image_refs (
        image_id TEXT PRIMARY KEY,
        ref_count INTEGER NOT NULL CHECK (ref_count >= 0),
        updated_at INTEGER NOT NULL
      )
    ''',
    'CREATE INDEX idx_image_refs_updated_at ON image_refs(updated_at)',
    '''
      CREATE TABLE person_mention_stats (
        archive_id TEXT PRIMARY KEY,
        mention_count INTEGER NOT NULL CHECK (mention_count >= 0),
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (archive_id) REFERENCES archives(id) ON DELETE CASCADE
      )
    ''',
    '''
      CREATE INDEX idx_person_mention_stats_count
      ON person_mention_stats(mention_count DESC)
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
    '''
      CREATE INDEX idx_media_source_refs_updated
      ON media_source_refs(source_updated_at DESC, image_id)
    ''',
    '''
      CREATE INDEX idx_media_source_refs_source
      ON media_source_refs(source_type, source_id)
    ''',
    'CREATE INDEX idx_media_source_refs_image ON media_source_refs(image_id)',
  ];
}
