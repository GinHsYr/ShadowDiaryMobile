import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/diary/diary_content_images.dart';

void main() {
  test('restores custom image sources sanitized by the HTML parser', () {
    const source = 'diary-image://123e4567-e89b-42d3-a456-426614174000.webp';
    final references = diaryImageReferencesFromHtml(
      '<p><img src="$source"></p>',
    );

    expect(references, hasLength(1));
    expect(references.single.source, source);
  });
}
