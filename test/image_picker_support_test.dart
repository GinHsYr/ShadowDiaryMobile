import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:shadow_diary_mobile/core/services/image_picker_support.dart';

void main() {
  test(
    'uses the image-only system picker with a maximum of nine images',
    () async {
      final originalPlatform = ImagePickerPlatform.instance;
      final fakePlatform = _FakeImagePickerPlatform(
        images: List.generate(12, (index) => XFile('image-$index.jpg')),
      );
      ImagePickerPlatform.instance = fakePlatform;
      addTearDown(() => ImagePickerPlatform.instance = originalPlatform);

      final paths = await pickGalleryImagePaths(20);

      expect(fakePlatform.requestedOptions?.limit, 9);
      expect(paths, hasLength(9));
      expect(paths, everyElement(endsWith('.jpg')));
    },
  );

  test('rejects a non-positive selection limit', () {
    expect(() => imagePickerSelectionLimit(0), throwsArgumentError);
  });
}

class _FakeImagePickerPlatform extends ImagePickerPlatform {
  _FakeImagePickerPlatform({required this.images});

  final List<XFile> images;
  MultiImagePickerOptions? requestedOptions;

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async {
    requestedOptions = options;
    return images;
  }
}
