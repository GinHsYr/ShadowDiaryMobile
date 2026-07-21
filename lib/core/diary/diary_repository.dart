import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'diary_entry.dart';
import 'diary_overview.dart';

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  throw StateError('DiaryRepository must be overridden at bootstrap.');
});

final diaryOverviewProvider = FutureProvider<DiaryOverview>((ref) {
  return ref.watch(diaryRepositoryProvider).loadOverview();
});

abstract interface class DiaryRepository {
  Future<DiaryEntry?> findById(String id);

  Future<DiaryEntry?> findByDate(DateTime date);

  Future<DiaryOverview> loadOverview();

  Future<void> save(DiaryEntry entry);
}

class SqliteDiaryRepository implements DiaryRepository {
  SqliteDiaryRepository(this._appDatabase, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _appDatabase;
  final DateTime Function() _now;

  @override
  Future<DiaryEntry?> findById(String id) async {
    final rows = await _appDatabase.database.query(
      'diary_entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  @override
  Future<DiaryEntry?> findByDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day + 1);
    final rows = await _appDatabase.database.query(
      'diary_entries',
      where: 'created_at >= ? AND created_at < ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'updated_at DESC',
    );
    for (final row in rows) {
      final entry = _fromRow(row);
      if (hasWrittenDiaryContent(
        title: entry.title,
        plainContent: entry.plainContent,
      )) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<DiaryOverview> loadOverview() async {
    final rows = await _appDatabase.database.query(
      'diary_entries',
      columns: ['created_at', 'title', 'plain_content'],
    );
    final entries = rows.map<DiaryOverviewSource>((row) {
      return (
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at']! as int,
        ),
        title: row['title']! as String,
        plainContent: row['plain_content']! as String,
      );
    });
    return calculateDiaryOverview(entries, today: _now());
  }

  @override
  Future<void> save(DiaryEntry entry) async {
    final values = <String, Object?>{
      'title': entry.title,
      'content': entry.content,
      'plain_content': entry.plainContent,
      'mood': entry.mood,
      'weather': entry.weather,
      'created_at': entry.createdAt.millisecondsSinceEpoch,
      'updated_at': entry.updatedAt.millisecondsSinceEpoch,
    };

    await _appDatabase.database.transaction((transaction) async {
      final updated = await transaction.update(
        'diary_entries',
        values,
        where: 'id = ?',
        whereArgs: [entry.id],
      );
      if (updated == 0) {
        await transaction.insert('diary_entries', {'id': entry.id, ...values});
      }
    });
  }

  DiaryEntry _fromRow(Map<String, Object?> row) {
    return DiaryEntry(
      id: row['id']! as String,
      title: row['title']! as String,
      content: row['content']! as String,
      plainContent: row['plain_content']! as String,
      mood: row['mood']! as String,
      weather: row['weather'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
    );
  }
}
