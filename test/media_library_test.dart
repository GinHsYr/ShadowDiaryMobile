import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/app/router.dart';
import 'package:shadow_diary_mobile/core/archives/archive.dart';
import 'package:shadow_diary_mobile/core/diary/diary_entry.dart';
import 'package:shadow_diary_mobile/core/media/media_library.dart';

void main() {
  test('collects every diary and archive image in update order', () {
    final older = DateTime(2026, 7, 20);
    final newer = DateTime(2026, 7, 21);
    final diary = DiaryEntry(
      id: 'diary-1',
      title: 'A day',
      content:
          '<p>Before</p><p><img src="file:///diary-one.webp"></p>'
          '<p><img src="file:///diary-two.webp"></p>',
      plainContent: 'Before',
      mood: 'calm',
      createdAt: older,
      updatedAt: older,
    );
    final archive = Archive(
      id: 'archive-1',
      name: 'Alice',
      type: ArchiveType.person,
      mainImage: '/archive-main.webp',
      images: const ['/archive-one.webp'],
      createdAt: newer,
      updatedAt: newer,
    );

    final library = buildMediaLibrary(
      diaryEntries: [diary],
      archives: [archive],
    );

    expect(library.items, hasLength(4));
    expect(library.diaryCount, 2);
    expect(library.archiveCount, 2);
    expect(library.items.map((item) => item.imageSource), [
      '/archive-main.webp',
      '/archive-one.webp',
      'file:///diary-one.webp',
      'file:///diary-two.webp',
    ]);
    expect(library.items.last.sourceImageIndex, 1);
  });

  test('source routes preserve image paths and occurrence indexes', () {
    const imageSource = 'file:///data/user/0/media/a b.webp';
    final diaryLocation = AppRoutes.editEntry(
      'entry/id',
      imageSource: imageSource,
      imageIndex: 3,
    );
    final archiveLocation = AppRoutes.editArchive(
      'archive/id',
      imagePath: '/data/media/a b.webp',
    );

    final diaryUri = Uri.parse(diaryLocation);
    final archiveUri = Uri.parse(archiveLocation);
    expect(diaryUri.path, '/entries/entry%2Fid/edit');
    expect(diaryUri.queryParameters['image'], imageSource);
    expect(diaryUri.queryParameters['imageIndex'], '3');
    expect(archiveUri.path, '/archives/archive%2Fid/edit');
    expect(archiveUri.queryParameters['image'], '/data/media/a b.webp');
  });
}
