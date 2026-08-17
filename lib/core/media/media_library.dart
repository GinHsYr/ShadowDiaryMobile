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
  final diaryRepository = ref.watch(diaryRepositoryProvider);
  final archiveRepository = ref.watch(archiveRepositoryProvider);
  final Future<Iterable<DiaryMediaSource>> diarySourcesFuture;
  if (diaryRepository is DiaryMediaRepository) {
    diarySourcesFuture = (diaryRepository as DiaryMediaRepository)
        .listDiaryMediaSources();
  } else {
    diarySourcesFuture = ref
        .watch(diaryEntryListProvider.future)
        .then((entries) => entries.map(_sourceFromDiary));
  }
  final Future<Iterable<ArchiveMediaSource>> archiveSourcesFuture;
  if (archiveRepository is ArchiveMediaRepository) {
    archiveSourcesFuture = (archiveRepository as ArchiveMediaRepository)
        .listArchiveMediaSources();
  } else {
    archiveSourcesFuture = ref
        .watch(archiveListProvider.future)
        .then((archives) => archives.map(_sourceFromArchive));
  }
  final resolvedDiarySources = await diarySourcesFuture;
  final resolvedArchiveSources = await archiveSourcesFuture;
  return buildMediaLibraryFromSources(
    diarySources: resolvedDiarySources,
    archiveSources: resolvedArchiveSources,
  );
});

DiaryMediaSource _sourceFromDiary(DiaryEntry entry) {
  return DiaryMediaSource(
    id: entry.id,
    title: entry.title,
    content: entry.content,
    createdAt: entry.createdAt,
    updatedAt: entry.updatedAt,
  );
}

ArchiveMediaSource _sourceFromArchive(Archive archive) {
  return ArchiveMediaSource(
    id: archive.id,
    name: archive.name,
    mainImage: archive.mainImage,
    images: archive.images,
    updatedAt: archive.updatedAt,
  );
}

MediaLibrary buildMediaLibraryFromSources({
  required Iterable<DiaryMediaSource> diarySources,
  required Iterable<ArchiveMediaSource> archiveSources,
}) {
  final items = <MediaItem>[];
  for (final entry in diarySources) {
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
  for (final archive in archiveSources) {
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
  _sortMediaItems(items);
  return MediaLibrary(List.unmodifiable(items));
}

MediaLibrary buildMediaLibrary({
  required Iterable<DiaryEntry> diaryEntries,
  required Iterable<Archive> archives,
}) {
  return buildMediaLibraryFromSources(
    diarySources: diaryEntries.map(_sourceFromDiary),
    archiveSources: archives.map(_sourceFromArchive),
  );
}

void _sortMediaItems(List<MediaItem> items) {
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
}
