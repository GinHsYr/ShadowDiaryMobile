import 'archive.dart';
import 'archive_index.dart';

List<Archive> searchArchives(Iterable<Archive> archives, String query) {
  return ArchiveDerivedIndex(archives).search(query);
}
