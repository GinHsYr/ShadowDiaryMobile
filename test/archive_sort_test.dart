import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/archives/archive.dart';
import 'package:shadow_diary_mobile/core/archives/archive_sort.dart';

void main() {
  test(
    'groups Chinese by pinyin, English case-insensitively, and symbols in #',
    () {
      final groups = groupAndSortArchives([
        _archive('symbol', '#收藏'),
        _archive('zhang', '张三'),
        _archive('alice-lower', 'alice'),
        _archive('number', '2Pac'),
        _archive('chen', '陈晨'),
        _archive('an', '安然'),
        _archive('alice-upper', 'Alice'),
      ]);

      expect(groups.map((group) => group.initial), ['A', 'C', 'Z', '#']);
      expect(groups[0].archives.map((archive) => archive.id), [
        'alice-upper',
        'alice-lower',
        'an',
      ]);
      expect(groups.last.archives.map((archive) => archive.id), [
        'symbol',
        'number',
      ]);
    },
  );

  test('uses the name instead of aliases as its sort key', () {
    final groups = groupAndSortArchives([_archive('z', '张三', alias: 'Alice')]);
    expect(groups.single.initial, 'Z');
  });
}

Archive _archive(String id, String name, {String? alias}) {
  final time = DateTime.fromMillisecondsSinceEpoch(1);
  return Archive(
    id: id,
    name: name,
    alias: alias,
    type: ArchiveType.person,
    createdAt: time,
    updatedAt: time,
  );
}
