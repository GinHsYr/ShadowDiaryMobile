import 'package:lpinyin/lpinyin.dart';

import 'archive.dart';

class ArchiveGroup {
  const ArchiveGroup({required this.initial, required this.archives});

  final String initial;
  final List<Archive> archives;
}

/// Precomputes pinyin and normalized search values for a stable archive list.
class ArchiveDerivedIndex {
  ArchiveDerivedIndex(Iterable<Archive> archives)
    : this._fromList(List<Archive>.unmodifiable(archives));

  ArchiveDerivedIndex._fromList(this.archives)
    : _records = _buildRecords(archives);

  final List<Archive> archives;
  final List<_ArchiveRecord> _records;

  List<Archive> search(String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return archives;
    return List<Archive>.unmodifiable(
      _records
          .where(
            (record) => record.searchValues.any(
              (value) => value.contains(normalizedQuery),
            ),
          )
          .map((record) => record.archive),
    );
  }

  List<ArchiveGroup> groupAndSort({String query = ''}) {
    final normalizedQuery = _normalize(query);
    final records = normalizedQuery.isEmpty
        ? _records
        : _records.where(
            (record) => record.searchValues.any(
              (value) => value.contains(normalizedQuery),
            ),
          );
    final grouped = <String, List<_ArchiveRecord>>{};
    for (final record in records) {
      grouped.putIfAbsent(record.initial, () => []).add(record);
    }
    final initials = grouped.keys.toList()
      ..sort((left, right) {
        if (left == '#') return right == '#' ? 0 : 1;
        if (right == '#') return -1;
        return left.compareTo(right);
      });
    return initials
        .map((initial) {
          final values = grouped[initial]!
            ..sort((left, right) {
              final byPinyin = left.sortKey.compareTo(right.sortKey);
              if (byPinyin != 0) return byPinyin;
              final byName = left.archive.name.compareTo(right.archive.name);
              if (byName != 0) return byName;
              return left.archive.createdAt.compareTo(right.archive.createdAt);
            });
          return ArchiveGroup(
            initial: initial,
            archives: List.unmodifiable(values.map((record) => record.archive)),
          );
        })
        .toList(growable: false);
  }
}

class _ArchiveRecord {
  const _ArchiveRecord({
    required this.archive,
    required this.initial,
    required this.sortKey,
    required this.searchValues,
  });

  final Archive archive;
  final String initial;
  final String sortKey;
  final List<String> searchValues;
}

List<_ArchiveRecord> _buildRecords(Iterable<Archive> archives) {
  return archives
      .map((archive) {
        final sortKey = archivePinyinSortKey(archive.name);
        final values = <String>[archive.name, ...archive.aliases];
        return _ArchiveRecord(
          archive: archive,
          initial: _archiveInitialFromKey(sortKey),
          sortKey: sortKey,
          searchValues: values
              .expand(_searchValues)
              .map(_normalize)
              .toList(growable: false),
        );
      })
      .toList(growable: false);
}

Iterable<String> _searchValues(String value) sync* {
  final normalized = _normalize(value);
  yield normalized;
  final pinyin = PinyinHelper.getPinyinE(value, separator: ' ', defPinyin: '#');
  yield _normalize(pinyin);
  yield _normalize(
    pinyin
        .split(RegExp(r'\s+'))
        .where((syllable) => syllable.isNotEmpty)
        .map((syllable) => syllable[0])
        .join(),
  );
}

String archivePinyinSortKey(String name) {
  final normalized = name.trim();
  if (normalized.isEmpty) return '';
  return PinyinHelper.getPinyinE(
    normalized,
    separator: '',
    defPinyin: '#',
  ).toUpperCase();
}

String archiveInitial(String name) {
  return _archiveInitialFromKey(archivePinyinSortKey(name));
}

String _archiveInitialFromKey(String key) {
  if (key.isEmpty) return '#';
  final firstCodeUnit = key.codeUnitAt(0);
  return firstCodeUnit >= 65 && firstCodeUnit <= 90 ? key[0] : '#';
}

final RegExp _searchSeparators = RegExp(r"[\s'’_-]+");

String _normalize(String value) {
  return value.trim().toLowerCase().replaceAll(_searchSeparators, '');
}
