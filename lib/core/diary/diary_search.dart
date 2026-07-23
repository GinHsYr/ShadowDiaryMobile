import 'diary_entry.dart';

class DiarySearchParams {
  const DiarySearchParams({
    this.keyword = '',
    this.mood,
    this.tags = const <String>[],
    this.dateFrom,
    this.dateTo,
    this.limit = 40,
    this.offset = 0,
  }) : assert(limit > 0),
       assert(offset >= 0);

  final String keyword;
  final String? mood;
  final List<String> tags;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int limit;
  final int offset;
}

class SearchHighlightKeyword {
  const SearchHighlightKeyword(this.value, {this.standalone = false});

  final String value;
  final bool standalone;
}

class DiarySearchResult {
  const DiarySearchResult({
    required this.entries,
    required this.total,
    this.expandedKeywords = const <String>[],
    this.highlightKeywords = const <SearchHighlightKeyword>[],
  });

  final List<DiaryEntry> entries;
  final int total;
  final List<String> expandedKeywords;
  final List<SearchHighlightKeyword> highlightKeywords;
}

abstract interface class DiarySearchRepository {
  Future<DiarySearchResult> searchDiaries(DiarySearchParams params);

  Future<List<String>> loadSearchHistory();

  Future<void> rememberSearch(String query);

  Future<void> clearSearchHistory();
}
