import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/archives/archive.dart';
import 'package:shadow_diary_mobile/core/archives/archive_search.dart';

void main() {
  final archives = <Archive>[
    _archive('zhang', '张三', alias: '小张;三哥\n老张'),
    _archive('li', '李雷', alias: '雷子'),
    _archive('alice', 'Alice', alias: 'Ally'),
  ];

  test('searches archive names by text, full pinyin, and initials', () {
    expect(_ids(searchArchives(archives, '张三')), ['zhang']);
    expect(_ids(searchArchives(archives, 'zhangsan')), ['zhang']);
    expect(_ids(searchArchives(archives, 'Zhang San')), ['zhang']);
    expect(_ids(searchArchives(archives, 'zs')), ['zhang']);
  });

  test('automatically searches aliases by text and pinyin', () {
    expect(_ids(searchArchives(archives, '小张')), ['zhang']);
    expect(_ids(searchArchives(archives, 'xiaozhang')), ['zhang']);
    expect(_ids(searchArchives(archives, 'xz')), ['zhang']);
    expect(_ids(searchArchives(archives, 'Sange')), ['zhang']);
    expect(_ids(searchArchives(archives, '老张')), ['zhang']);
    expect(_ids(searchArchives(archives, 'ally')), ['alice']);
  });

  test('returns all archives for a blank query and none when unmatched', () {
    expect(_ids(searchArchives(archives, '  ')), ['zhang', 'li', 'alice']);
    expect(searchArchives(archives, 'wangwu'), isEmpty);
  });
}

Iterable<String> _ids(Iterable<Archive> archives) {
  return archives.map((archive) => archive.id);
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
