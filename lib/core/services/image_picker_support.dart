import 'package:image_picker/image_picker.dart';

const maxImagesPerPickerSelection = 9;

int imagePickerSelectionLimit(int requestedLimit) {
  if (requestedLimit < 1) {
    throw ArgumentError.value(
      requestedLimit,
      'requestedLimit',
      'must be positive',
    );
  }
  return requestedLimit.clamp(1, maxImagesPerPickerSelection).toInt();
}

Future<List<String>> pickGalleryImagePaths(int requestedLimit) async {
  final limit = imagePickerSelectionLimit(requestedLimit);
  final images = await ImagePicker().pickMultiImage(limit: limit);
  return images
      .map((image) => image.path)
      .where((path) => path.isNotEmpty)
      .take(limit)
      .toList(growable: false);
}
