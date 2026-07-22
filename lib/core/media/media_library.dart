import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../archives/archive.dart';
import '../archives/archive_repository.dart';
import '../diary/diary_content_images.dart';
import '../diary/diary_entry.dart';
import '../diary/diary_repository.dart';

enum MediaSourceType { diary, archive }

class MediaItem {
  const MediaItem({
    required this.id,
    required this.imageSource,
    required this.sourceType,
    required this.sourceId,
    required this.sourceTitle,
    required this.sourceImageIndex,
    required this.sourceDate,
    required this.updatedAt,
  });

  final String id;
  final String imageSource;
  final MediaSourceType sourceType;
  final String sourceId;
  final String sourceTitle;
  final int sourceImageIndex;
  final DateTime sourceDate;
  final DateTime updatedAt;
}

class MediaLibrary {
  const MediaLibrary(this.items);

  final List<MediaItem> items;

  int get diaryCount =>
      items.where((item) => item.sourceType == MediaSourceType.diary).length;

  int get archiveCount => items.length - diaryCount;
}

final mediaLibraryProvider = FutureProvider<MediaLibrary>((ref) async {
  final diaryEntriesFuture = ref.watch(diaryEntryListProvider.future);
  final archivesFuture = ref.watch(archiveListProvider.future);
  final diaryEntries = await diaryEntriesFuture;
  final archives = await archivesFuture;
  return buildMediaLibrary(diaryEntries: diaryEntries, archives: archives);
});

MediaLibrary buildMediaLibrary({
  required Iterable<DiaryEntry> diaryEntries,
  required Iterable<Archive> archives,
}) {
  final items = <MediaItem>[];
  for (final entry in diaryEntries) {
    final references = diaryImageReferencesFromHtml(entry.content);
    for (final reference in references) {
      items.add(
        MediaItem(
          id: 'diary:${entry.id}:${reference.imageIndex}',
          imageSource: reference.source,
          sourceType: MediaSourceType.diary,
          sourceId: entry.id,
          sourceTitle: entry.title.trim(),
          sourceImageIndex: reference.imageIndex,
          sourceDate: entry.createdAt,
          updatedAt: entry.updatedAt,
        ),
      );
    }
  }

  for (final archive in archives) {
    final imagePaths = <String>[?archive.mainImage, ...archive.images];
    for (var index = 0; index < imagePaths.length; index++) {
      final path = imagePaths[index].trim();
      if (path.isEmpty) continue;
      items.add(
        MediaItem(
          id: 'archive:${archive.id}:$index',
          imageSource: path,
          sourceType: MediaSourceType.archive,
          sourceId: archive.id,
          sourceTitle: archive.name.trim(),
          sourceImageIndex: index,
          sourceDate: archive.updatedAt,
          updatedAt: archive.updatedAt,
        ),
      );
    }
  }

  items.sort((left, right) {
    final dateComparison = right.updatedAt.compareTo(left.updatedAt);
    if (dateComparison != 0) return dateComparison;
    final typeComparison = left.sourceType.index.compareTo(
      right.sourceType.index,
    );
    if (typeComparison != 0) return typeComparison;
    final idComparison = left.sourceId.compareTo(right.sourceId);
    if (idComparison != 0) return idComparison;
    return left.sourceImageIndex.compareTo(right.sourceImageIndex);
  });
  return MediaLibrary(List.unmodifiable(items));
}
