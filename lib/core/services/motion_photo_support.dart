import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

const motionPhotoFileSuffix = '_motion.mp4';
const _motionPhotoScanChunkSize = 64 * 1024;
const _motionPhotoHeaderOverlap = 7;

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
  int? offset;
  try {
    offset = await _embeddedMotionPhotoVideoOffsetInFile(source);
  } on FileSystemException {
    return false;
  }
  if (offset == null) return false;

  final temporary = File('${destination.path}.part');
  try {
    await destination.parent.create(recursive: true);
    if (await temporary.exists()) await temporary.delete();
    final output = temporary.openWrite();
    try {
      await output.addStream(source.openRead(offset));
      await output.flush();
    } finally {
      await output.close();
    }
    final expectedLength = await source.length() - offset;
    if (await temporary.length() != expectedLength) {
      throw FileSystemException(
        'Motion photo source changed during extraction.',
        source.path,
      );
    }
    if (await destination.exists()) await destination.delete();
    await temporary.rename(destination.path);
    return true;
  } on Object {
    try {
      if (await temporary.exists()) await temporary.delete();
    } on FileSystemException {
      // A stale partial file can be cleaned on the next extraction attempt.
    }
    rethrow;
  }
}

Future<int?> _embeddedMotionPhotoVideoOffsetInFile(File source) async {
  final fileLength = await source.length();
  if (fileLength < 16) return null;

  final input = await source.open();
  var processed = 0;
  var overlap = Uint8List(0);
  int? candidate;
  try {
    while (processed < fileLength) {
      final remaining = fileLength - processed;
      final chunk = await input.read(
        remaining < _motionPhotoScanChunkSize
            ? remaining
            : _motionPhotoScanChunkSize,
      );
      if (chunk.isEmpty) break;

      final window = Uint8List(overlap.length + chunk.length)
        ..setRange(0, overlap.length, overlap)
        ..setRange(overlap.length, overlap.length + chunk.length, chunk);
      final windowOffset = processed - overlap.length;
      for (var index = 4; index + 4 <= window.length; index++) {
        final markerOffset = windowOffset + index;
        if (markerOffset < 8 || markerOffset + 12 > fileLength) continue;
        if (window[index] != 0x66 ||
            window[index + 1] != 0x74 ||
            window[index + 2] != 0x79 ||
            window[index + 3] != 0x70) {
          continue;
        }
        final boxStart = markerOffset - 4;
        if (boxStart < 1024) continue;
        final boxSize = _readUint32(window, index - 4);
        if (boxSize < 8 || boxStart + boxSize > fileLength) continue;
        candidate = boxStart;
      }

      processed += chunk.length;
      final overlapLength = window.length < _motionPhotoHeaderOverlap
          ? window.length
          : _motionPhotoHeaderOverlap;
      overlap = Uint8List.fromList(
        window.sublist(window.length - overlapLength),
      );
    }
  } finally {
    await input.close();
  }
  return candidate;
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
