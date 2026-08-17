import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

const motionPhotoFileSuffix = '_motion.mp4';

const _imageExtensions = <String>{
  '.avif',
  '.gif',
  '.heic',
  '.heif',
  '.jpeg',
  '.jpg',
  '.png',
  '.webp',
};

class MotionPhotoSelection {
  const MotionPhotoSelection({required this.imagePath, this.motionPath});

  final String imagePath;
  final String? motionPath;
}

List<MotionPhotoSelection> imageSelectionsFromPaths(
  Iterable<String> paths, {
  required int maxImages,
}) {
  return paths
      .where(
        (path) => _imageExtensions.contains(p.extension(path).toLowerCase()),
      )
      .take(maxImages)
      .map((imagePath) => MotionPhotoSelection(imagePath: imagePath))
      .toList(growable: false);
}

String motionPhotoFileName(String imageId) => '$imageId$motionPhotoFileSuffix';

Future<bool> storeMotionPhotoVideo({
  required String imagePath,
  required String? pairedMotionPath,
  required String destinationPath,
}) async {
  if (pairedMotionPath != null) {
    await File(pairedMotionPath).copy(destinationPath);
    return true;
  }
  return extractEmbeddedMotionPhotoVideo(
    File(imagePath),
    File(destinationPath),
  );
}

Future<bool> extractEmbeddedMotionPhotoVideo(
  File source,
  File destination,
) async {
  Uint8List bytes;
  try {
    bytes = await source.readAsBytes();
  } on FileSystemException {
    return false;
  }
  final offset = embeddedMotionPhotoVideoOffset(bytes);
  if (offset == null) return false;
  await destination.writeAsBytes(bytes.sublist(offset), flush: true);
  return true;
}

int? embeddedMotionPhotoVideoOffset(List<int> bytes) {
  int? candidate;
  for (var index = 8; index + 12 <= bytes.length; index++) {
    if (bytes[index] != 0x66 ||
        bytes[index + 1] != 0x74 ||
        bytes[index + 2] != 0x79 ||
        bytes[index + 3] != 0x70) {
      continue;
    }
    final boxStart = index - 4;
    if (boxStart < 1024) continue;
    final boxSize = _readUint32(bytes, boxStart);
    if (boxSize < 8 || boxStart + boxSize > bytes.length) continue;
    candidate = boxStart;
  }
  return candidate;
}

int _readUint32(List<int> bytes, int offset) {
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}
