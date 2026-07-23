import 'package:lpinyin/lpinyin.dart';

import 'archive.dart';

final RegExp _searchSeparators = RegExp(r"[\s'’_-]+");

List<Archive> searchArchives(Iterable<Archive> archives, String query) {
  final normalizedQuery = _normalize(query);
  if (normalizedQuery.isEmpty) {
    return List<Archive>.unmodifiable(archives);
  }

  return List<Archive>.unmodifiable(
    archives.where(
      (archive) => <String>[
        archive.name,
        ...archive.aliases,
      ].any((value) => _matchesSearchValue(value, normalizedQuery)),
    ),
  );
}

bool _matchesSearchValue(String value, String normalizedQuery) {
  if (_normalize(value).contains(normalizedQuery)) return true;

  final pinyin = PinyinHelper.getPinyinE(value, separator: ' ', defPinyin: '#');
  if (_normalize(pinyin).contains(normalizedQuery)) return true;

  final initials = pinyin
      .split(RegExp(r'\s+'))
      .where((syllable) => syllable.isNotEmpty)
      .map((syllable) => syllable[0])
      .join();
  return _normalize(initials).contains(normalizedQuery);
}

String _normalize(String value) {
  return value.trim().toLowerCase().replaceAll(_searchSeparators, '');
}
