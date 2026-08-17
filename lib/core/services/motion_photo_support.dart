import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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
const _videoExtensions = <String>{'.mov', '.mp4', '.m4v', '.3gp'};

class MotionPhotoSelection {
  const MotionPhotoSelection({required this.imagePath, this.motionPath});

  final String imagePath;
  final String? motionPath;
}

Future<List<String>> pickMotionPhotoPaths(int maxImages) async {
  final result = await FilePicker.pickFiles(
    allowMultiple: true,
    type: FileType.custom,
    allowedExtensions: [
      ..._imageExtensions.map((extension) => extension.substring(1)),
      ..._videoExtensions.map((extension) => extension.substring(1)),
    ],
  );
  if (result == null) return const [];
  return result.files
      .map((file) => file.path)
      .whereType<String>()
      .take(maxImages * 2)
      .toList(growable: false);
}

List<MotionPhotoSelection> pairMotionPhotoSelections(
  Iterable<String> paths, {
  required int maxImages,
}) {
  final images = <String>[];
  final videosByStem = <String, String>{};
  for (final path in paths) {
    final extension = p.extension(path).toLowerCase();
    final stem = p.basenameWithoutExtension(path).toLowerCase();
    if (_imageExtensions.contains(extension)) {
      images.add(path);
    } else if (_videoExtensions.contains(extension)) {
      videosByStem.putIfAbsent(stem, () => path);
    }
  }
  return images
      .take(maxImages)
      .map(
        (imagePath) => MotionPhotoSelection(
          imagePath: imagePath,
          motionPath:
              videosByStem[p.basenameWithoutExtension(imagePath).toLowerCase()],
        ),
      )
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
