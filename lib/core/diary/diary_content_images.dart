import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';

class DiaryImageReference {
  const DiaryImageReference({
    required this.source,
    required this.imageIndex,
    required this.documentOffset,
  });

  final String source;
  final int imageIndex;
  final int documentOffset;
}

List<DiaryImageReference> diaryImageReferencesFromHtml(String html) {
  if (html.trim().isEmpty) return const [];
  try {
    return diaryImageReferencesFromDelta(HtmlToDelta().convert(html));
  } on Object {
    return const [];
  }
}

List<DiaryImageReference> diaryImageReferencesFromDelta(Delta delta) {
  final references = <DiaryImageReference>[];
  var documentOffset = 0;
  for (final operation in delta.toJson()) {
    final insertion = operation['insert'];
    if (insertion is Map) {
      final source = insertion['image'];
      if (source is String && source.trim().isNotEmpty) {
        references.add(
          DiaryImageReference(
            source: source,
            imageIndex: references.length,
            documentOffset: documentOffset,
          ),
        );
      }
    }
    documentOffset += _operationLength(operation);
  }
  return List.unmodifiable(references);
}

int _operationLength(Map<String, dynamic> operation) {
  final insertion = operation['insert'];
  if (insertion is String) return insertion.length;
  if (insertion != null) return 1;
  return (operation['retain'] as int?) ?? (operation['delete'] as int?) ?? 0;
}
