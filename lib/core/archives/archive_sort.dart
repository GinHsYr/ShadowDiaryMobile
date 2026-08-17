import 'archive.dart';
import 'archive_index.dart';

export 'archive_index.dart'
    show ArchiveGroup, archiveInitial, archivePinyinSortKey;

List<ArchiveGroup> groupAndSortArchives(Iterable<Archive> archives) {
  return ArchiveDerivedIndex(archives).groupAndSort();
}
