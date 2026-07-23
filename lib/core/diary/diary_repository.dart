import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../archives/archive.dart';
import '../database/app_database.dart';
import 'diary_entry.dart';
import 'diary_overview.dart';
import 'diary_search.dart';

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  throw StateError('DiaryRepository must be overridden at bootstrap.');
});

final diaryOverviewProvider = FutureProvider<DiaryOverview>((ref) {
  return ref.watch(diaryRepositoryProvider).loadOverview();
});

final diaryEntryListProvider = FutureProvider<List<DiaryEntry>>((ref) {
  return ref.watch(diaryRepositoryProvider).listEntries();
});

final diarySearchRepositoryProvider = Provider<DiarySearchRepository>((ref) {
  final Object repository = ref.watch(diaryRepositoryProvider);
  if (repository is DiarySearchRepository) return repository;
  throw StateError('DiarySearchRepository must be overridden at bootstrap.');
});

abstract interface class DiaryRepository {
  Future<List<DiaryEntry>> listEntries();

  Future<DiaryEntry?> findById(String id);

  Future<DiaryEntry?> findByDate(DateTime date);

  Future<DiaryOverview> loadOverview();

  Future<void> save(DiaryEntry entry);
}

class SqliteDiaryRepository implements DiaryRepository, DiarySearchRepository {
  SqliteDiaryRepository(this._appDatabase, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _appDatabase;
  final DateTime Function() _now;

  static const _searchHistoryKey = 'diary.search_history';
  static const _maximumHistoryLength = 10;

  @override
  Future<List<DiaryEntry>> listEntries() async {
    final rows = await _appDatabase.database.query(
      'diary_entries',
      orderBy: 'updated_at DESC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

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

  @override
  Future<DiarySearchResult> searchDiaries(DiarySearchParams params) async {
    final keywordGroups = await _buildKeywordGroups(params.keyword);
    final query = _buildSearchQuery(params, keywordGroups);
    final requiresPostFilter = keywordGroups.any(
      (group) => group.any((keyword) => keyword.standalone),
    );
    final limit = params.limit.clamp(1, 100);
    final offset = params.offset;

    late final List<Map<String, Object?>> rows;
    late final int total;
    if (requiresPostFilter) {
      final candidates = await _appDatabase.database.rawQuery(
        '${_entrySelect()} ${query.whereSql} '
        'ORDER BY e.created_at DESC',
        query.arguments,
      );
      final matches = candidates
          .where((row) => _rowMatchesKeywordGroups(row, keywordGroups))
          .toList(growable: false);
      total = matches.length;
      rows = matches.skip(offset).take(limit).toList(growable: false);
    } else {
      final countRows = await _appDatabase.database.rawQuery(
        'SELECT COUNT(*) AS total FROM diary_entries e ${query.whereSql}',
        query.arguments,
      );
      total = countRows.single['total']! as int;
      rows = await _appDatabase.database.rawQuery(
        '${_entrySelect()} ${query.whereSql} '
        'ORDER BY e.created_at DESC LIMIT ? OFFSET ?',
        [...query.arguments, limit, offset],
      );
    }

    final highlightKeywords = _flattenKeywords(keywordGroups);
    return DiarySearchResult(
      entries: rows.map(_fromRow).toList(growable: false),
      total: total,
      expandedKeywords: highlightKeywords
          .map((keyword) => keyword.value)
          .toList(growable: false),
      highlightKeywords: highlightKeywords,
    );
  }

  @override
  Future<List<String>> loadSearchHistory() async {
    final rows = await _appDatabase.database.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_searchHistoryKey],
      limit: 1,
    );
    if (rows.isEmpty) return const <String>[];

    try {
      final decoded = jsonDecode(rows.single['value']! as String);
      if (decoded is! List<Object?>) return const <String>[];
      return decoded
          .whereType<String>()
          .map((query) => query.trim())
          .where((query) => query.isNotEmpty)
          .take(_maximumHistoryLength)
          .toList(growable: false);
    } on FormatException {
      return const <String>[];
    }
  }

  @override
  Future<void> rememberSearch(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;

    final history = await loadSearchHistory();
    final normalizedLower = normalized.toLowerCase();
    final updated = <String>[
      normalized,
      ...history.where((item) => item.toLowerCase() != normalizedLower),
    ].take(_maximumHistoryLength).toList(growable: false);
    await _appDatabase.database.insert('settings', {
      'key': _searchHistoryKey,
      'value': jsonEncode(updated),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> clearSearchHistory() async {
    await _appDatabase.database.delete(
      'settings',
      where: 'key = ?',
      whereArgs: [_searchHistoryKey],
    );
  }

  Future<List<List<_ExpandedKeyword>>> _buildKeywordGroups(
    String keyword,
  ) async {
    final rawGroups = keyword
        .trim()
        .split(RegExp(r'\s+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    final groups = <List<_ExpandedKeyword>>[];
    for (final rawGroup in rawGroups) {
      groups.add(await _expandKeyword(rawGroup));
    }
    return groups;
  }

  Future<List<_ExpandedKeyword>> _expandKeyword(String rawKeyword) async {
    final pattern = '%${_escapeLike(rawKeyword)}%';
    final rows = await _appDatabase.database.rawQuery(
      r'''
        SELECT name, alias
        FROM archives
        WHERE name LIKE ? ESCAPE '\' COLLATE NOCASE
           OR alias LIKE ? ESCAPE '\' COLLATE NOCASE
      ''',
      [pattern, pattern],
    );
    if (rows.isEmpty) {
      return [_ExpandedKeyword(rawKeyword)];
    }

    final normalizedKeyword = rawKeyword.toLowerCase();
    final matches = rows
        .map((row) {
          final values = <String>[
            row['name']! as String,
            ...splitArchiveAliases(row['alias'] as String?),
          ];
          return (
            values: values,
            exact: values.any(
              (value) => value.toLowerCase() == normalizedKeyword,
            ),
          );
        })
        .toList(growable: false);
    final exactMatches = matches.where((match) => match.exact).toList();
    final candidates = exactMatches.isNotEmpty ? exactMatches : matches;
    final expanded = <_ExpandedKeyword>[
      if (exactMatches.isEmpty) _ExpandedKeyword(rawKeyword),
      for (final match in candidates)
        for (final value in match.values)
          _ExpandedKeyword(value, standalone: value.runes.length == 1),
    ];
    return _deduplicateKeywords(expanded);
  }

  _SearchQuery _buildSearchQuery(
    DiarySearchParams params,
    List<List<_ExpandedKeyword>> keywordGroups,
  ) {
    final clauses = <String>[];
    final arguments = <Object?>[];

    if (keywordGroups.isNotEmpty) {
      final canUseFts = keywordGroups.every(
        (group) => group.any((keyword) => _containsWordLike(keyword.value)),
      );
      final likeGroups = keywordGroups
          .map((group) {
            final alternatives = group
                .map((keyword) {
                  final pattern = '%${_escapeLike(keyword.value)}%';
                  arguments
                    ..add(pattern)
                    ..add(pattern);
                  return "(e.title LIKE ? ESCAPE '\\' COLLATE NOCASE OR "
                      "e.plain_content LIKE ? ESCAPE '\\' COLLATE NOCASE)";
                })
                .join(' OR ');
            return '($alternatives)';
          })
          .join(' AND ');
      if (canUseFts) {
        final ftsGroups = keywordGroups
            .map((group) {
              final alternatives = group
                  .where((keyword) => _containsWordLike(keyword.value))
                  .map((keyword) => _quoteFts(keyword.value))
                  .join(' OR ');
              return '($alternatives)';
            })
            .join(' AND ');
        clauses.add(
          '(e.rowid IN ('
          'SELECT rowid FROM diary_search_fts '
          'WHERE diary_search_fts MATCH ?'
          ') OR ($likeGroups))',
        );
        arguments.insert(0, ftsGroups);
      } else {
        clauses.add('($likeGroups)');
      }
    }

    final mood = params.mood?.trim();
    if (mood != null && mood.isNotEmpty) {
      clauses.add('e.mood = ?');
      arguments.add(mood);
    }

    if (params.dateFrom case final dateFrom?) {
      final start = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
      clauses.add('e.created_at >= ?');
      arguments.add(start.millisecondsSinceEpoch);
    }
    if (params.dateTo case final dateTo?) {
      final exclusiveEnd = DateTime(dateTo.year, dateTo.month, dateTo.day + 1);
      clauses.add('e.created_at < ?');
      arguments.add(exclusiveEnd.millisecondsSinceEpoch);
    }

    final tags = params.tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (tags.isNotEmpty) {
      final placeholders = List.filled(tags.length, '?').join(', ');
      clauses.add(
        'e.id IN ('
        'SELECT dt.diary_id FROM diary_tags dt '
        'JOIN tags t ON dt.tag_id = t.id '
        'WHERE t.name IN ($placeholders) '
        'GROUP BY dt.diary_id '
        'HAVING COUNT(DISTINCT t.name) = ?'
        ')',
      );
      arguments
        ..addAll(tags)
        ..add(tags.length);
    }

    final whereSql = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    return _SearchQuery(whereSql, arguments);
  }

  bool _rowMatchesKeywordGroups(
    Map<String, Object?> row,
    List<List<_ExpandedKeyword>> keywordGroups,
  ) {
    final text = '${row['title']}\n${row['plain_content']}';
    final normalizedText = text.toLowerCase();
    return keywordGroups.every(
      (group) => group.any((keyword) {
        final normalizedKeyword = keyword.value.toLowerCase();
        if (!keyword.standalone) {
          return normalizedText.contains(normalizedKeyword);
        }
        return _hasStandaloneMatch(normalizedText, normalizedKeyword);
      }),
    );
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

  String _entrySelect() {
    return 'SELECT e.id, e.title, e.content, e.plain_content, e.mood, '
        'e.weather, e.created_at, e.updated_at FROM diary_entries e';
  }
}

class _ExpandedKeyword {
  const _ExpandedKeyword(this.value, {this.standalone = false});

  final String value;
  final bool standalone;
}

class _SearchQuery {
  const _SearchQuery(this.whereSql, this.arguments);

  final String whereSql;
  final List<Object?> arguments;
}

List<_ExpandedKeyword> _deduplicateKeywords(
  Iterable<_ExpandedKeyword> keywords,
) {
  final values = <String, _ExpandedKeyword>{};
  for (final keyword in keywords) {
    final value = keyword.value.trim();
    if (value.isEmpty) continue;
    final key = value.toLowerCase();
    final existing = values[key];
    if (existing == null || (existing.standalone && !keyword.standalone)) {
      values[key] = _ExpandedKeyword(value, standalone: keyword.standalone);
    }
  }
  return values.values.toList(growable: false);
}

List<SearchHighlightKeyword> _flattenKeywords(
  Iterable<Iterable<_ExpandedKeyword>> groups,
) {
  final flattened = _deduplicateKeywords(groups.expand((group) => group));
  return flattened
      .map(
        (keyword) => SearchHighlightKeyword(
          keyword.value,
          standalone: keyword.standalone,
        ),
      )
      .toList(growable: false);
}

String _escapeLike(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}

String _quoteFts(String value) {
  return '"${value.replaceAll('"', '""')}"';
}

bool _hasStandaloneMatch(String text, String keyword) {
  var index = text.indexOf(keyword);
  while (index != -1) {
    final previous = _runeBefore(text, index);
    final next = _runeAfter(text, index + keyword.length);
    if (!_isWordLike(previous) && !_isWordLike(next)) return true;
    index = text.indexOf(keyword, index + keyword.length);
  }
  return false;
}

String? _runeBefore(String text, int index) {
  if (index <= 0) return null;
  var start = index - 1;
  if (start > 0 &&
      _isLowSurrogate(text.codeUnitAt(start)) &&
      _isHighSurrogate(text.codeUnitAt(start - 1))) {
    start--;
  }
  return text.substring(start, index);
}

String? _runeAfter(String text, int index) {
  if (index >= text.length) return null;
  var end = index + 1;
  if (_isHighSurrogate(text.codeUnitAt(index)) &&
      end < text.length &&
      _isLowSurrogate(text.codeUnitAt(end))) {
    end++;
  }
  return text.substring(index, end);
}

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

final RegExp _wordLikeCharacter = RegExp(r'^[\p{L}\p{N}]$', unicode: true);

bool _isWordLike(String? character) {
  return character != null && _wordLikeCharacter.hasMatch(character);
}

bool _containsWordLike(String value) {
  return value.runes.any((rune) => _isWordLike(String.fromCharCode(rune)));
}
