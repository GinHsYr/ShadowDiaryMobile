import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/features/editor/diary_document_codec.dart';

void main() {
  test('preserves a WebP image percentage width through HTML', () {
    final document = Document.fromJson([
      {
        'insert': {'image': 'file:///data/user/0/app/photo.webp'},
        'attributes': {'width': '45%'},
      },
      {'insert': '\n'},
    ]);

    final html = diaryDocumentToHtml(document);
    final restored = diaryDocumentFromHtml(html);
    final imageOperation = restored.toDelta().toJson().first;
    final attributes = imageOperation['attributes'] as Map<String, dynamic>;

    expect(html, contains('photo.webp'));
    expect(html, contains('width:45%'));
    expect(attributes[Attribute.width.key], '45%');
  });
}
