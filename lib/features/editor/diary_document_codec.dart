import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

Document diaryDocumentFromHtml(String html) {
  final delta = HtmlToDelta().convert(html);
  final normalized = _normalizeImageAttributes(
    delta,
    centeredImageIndexes: _centeredImageIndexes(html),
  );
  return normalized.isEmpty ? Document() : Document.fromDelta(normalized);
}

Set<int> _centeredImageIndexes(String html) {
  final indexes = <int>{};
  final imageTags = RegExp(
    r'''<img\b(?:[^>"']+|"[^"]*"|'[^']*')*>''',
    caseSensitive: false,
  ).allMatches(html);
  var index = 0;
  for (final match in imageTags) {
    final tag = match.group(0)!;
    final hasCenterClass = RegExp(
      r'''\bclass\s*=\s*(["'])[^"']*\bql-align-center\b''',
      caseSensitive: false,
    ).hasMatch(tag);
    final hasCenterStyle = RegExp(
      r'''(?:text-align\s*:\s*center|margin-(?:left|right)\s*:\s*auto)''',
      caseSensitive: false,
    ).hasMatch(tag);
    if (hasCenterClass || hasCenterStyle) indexes.add(index);
    index++;
  }
  return indexes;
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
          if (operation.attributes.align?.value ==
              Attribute.centerAlignment.value)
            'display:block',
          if (operation.attributes.align?.value ==
              Attribute.centerAlignment.value)
            'margin-left:auto',
          if (operation.attributes.align?.value ==
              Attribute.centerAlignment.value)
            'margin-right:auto',
        ];
      },
    ),
  );
  return QuillDeltaToHtmlConverter(
    document.toDelta().toJson(),
    options,
  ).convert();
}

Delta _normalizeImageAttributes(
  Delta delta, {
  Set<int> centeredImageIndexes = const {},
}) {
  var imageIndex = 0;
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
      if (RegExp(
        r'text-align\s*:\s*center',
        caseSensitive: false,
      ).hasMatch(style)) {
        attributes[Attribute.align.key] = Attribute.centerAlignment.value;
      }
      attributes.remove(Attribute.style.key);
    }

    if (centeredImageIndexes.contains(imageIndex)) {
      attributes[Attribute.align.key] = Attribute.centerAlignment.value;
    }
    imageIndex++;

    if (attributes.isEmpty) {
      operation.remove('attributes');
    } else {
      operation['attributes'] = attributes;
    }
    return operation;
  }).toList();
  return Delta.fromJson(operations);
}
