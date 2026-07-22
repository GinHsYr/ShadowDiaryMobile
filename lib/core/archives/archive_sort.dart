import 'package:lpinyin/lpinyin.dart';

import 'archive.dart';

class ArchiveGroup {
  const ArchiveGroup({required this.initial, required this.archives});

  final String initial;
  final List<Archive> archives;
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
  final key = archivePinyinSortKey(name);
  if (key.isEmpty) return '#';
  final firstCodeUnit = key.codeUnitAt(0);
  return firstCodeUnit >= 65 && firstCodeUnit <= 90 ? key[0] : '#';
}

List<ArchiveGroup> groupAndSortArchives(Iterable<Archive> archives) {
  final grouped = <String, List<Archive>>{};
  for (final archive in archives) {
    grouped.putIfAbsent(archiveInitial(archive.name), () => []).add(archive);
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
            final byPinyin = archivePinyinSortKey(
              left.name,
            ).compareTo(archivePinyinSortKey(right.name));
            if (byPinyin != 0) return byPinyin;
            final byName = left.name.compareTo(right.name);
            if (byName != 0) return byName;
            return left.createdAt.compareTo(right.createdAt);
          });
        return ArchiveGroup(
          initial: initial,
          archives: List.unmodifiable(values),
        );
      })
      .toList(growable: false);
}
