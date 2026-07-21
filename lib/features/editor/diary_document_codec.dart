import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

Document diaryDocumentFromHtml(String html) {
  final delta = HtmlToDelta().convert(html);
  final normalized = _normalizeImageAttributes(delta);
  return normalized.isEmpty ? Document() : Document.fromDelta(normalized);
}

String diaryDocumentToHtml(Document document) {
  final options = ConverterOptions(
    converterOptions: OpConverterOptions(
      customCssStyles: (operation) {
        if (!operation.isImage()) return null;
        final width = operation.attributes.width;
        return <String>[
          'max-width:100%',
          'height:auto',
          if (width != null) 'width:$width',
        ];
      },
    ),
  );
  return QuillDeltaToHtmlConverter(
    document.toDelta().toJson(),
    options,
  ).convert();
}

Delta _normalizeImageAttributes(Delta delta) {
  final operations = delta.toJson().map<Map<String, dynamic>>((rawOperation) {
    final operation = Map<String, dynamic>.from(rawOperation);
    final insert = operation['insert'];
    if (insert is! Map || !insert.containsKey(BlockEmbed.imageType)) {
      return operation;
    }

    final rawAttributes = operation['attributes'];
    final attributes = rawAttributes is Map
        ? Map<String, dynamic>.from(rawAttributes)
        : <String, dynamic>{};
    final style = attributes[Attribute.style.key];
    if (style is String) {
      final imageStyles = parseImageStyleAttribute(style, '');
      final width = imageStyles[Attribute.width.key];
      if (width != null) attributes[Attribute.width.key] = width.toString();
      attributes.remove(Attribute.style.key);
    }

    if (attributes.isEmpty) {
      operation.remove('attributes');
    } else {
      operation['attributes'] = attributes;
    }
    return operation;
  }).toList();
  return Delta.fromJson(operations);
}
