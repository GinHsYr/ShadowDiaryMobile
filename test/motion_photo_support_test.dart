import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/services/motion_photo_support.dart';

void main() {
  test('keeps still images and ignores video paths', () {
    final selections = imageSelectionsFromPaths(const [
      r'C:\photos\IMG_0001.HEIC',
      r'C:\photos\IMG_0001.MOV',
      r'C:\photos\IMG_0002.JPG',
    ], maxImages: 9);

    expect(selections, hasLength(2));
    expect(
      selections.map((selection) => selection.motionPath),
      everyElement(isNull),
    );
  });

  test('finds an embedded ISO-BMFF motion video after the poster bytes', () {
    final bytes = Uint8List(2048);
    const boxStart = 1400;
    const boxSize = 120;
    bytes[boxStart] = 0;
    bytes[boxStart + 1] = 0;
    bytes[boxStart + 2] = 0;
    bytes[boxStart + 3] = boxSize;
    bytes.setRange(boxStart + 4, boxStart + 8, 'ftyp'.codeUnits);

    expect(embeddedMotionPhotoVideoOffset(bytes), boxStart);
  });

  test('ignores ordinary still images without an embedded video', () {
    expect(embeddedMotionPhotoVideoOffset(Uint8List(4096)), isNull);
  });

  test('streams an embedded video whose header crosses a scan chunk', () async {
    final root = await Directory.systemTemp.createTemp(
      'shadow-diary-motion-photo-',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final source = File('${root.path}/source.jpg');
    final destination = File('${root.path}/motion.mp4');
    final bytes = Uint8List(64 * 1024 + 2048);
    const boxStart = 64 * 1024 - 5;
    const boxSize = 512;
    bytes[boxStart] = 0;
    bytes[boxStart + 1] = 0;
    bytes[boxStart + 2] = boxSize >> 8;
    bytes[boxStart + 3] = boxSize & 0xff;
    bytes.setRange(boxStart + 4, boxStart + 8, 'ftyp'.codeUnits);
    for (var index = boxStart + 8; index < bytes.length; index++) {
      bytes[index] = index % 251;
    }
    await source.writeAsBytes(bytes);

    expect(await extractEmbeddedMotionPhotoVideo(source, destination), isTrue);
    expect(await destination.readAsBytes(), bytes.sublist(boxStart));
    expect(await File('${destination.path}.part').exists(), isFalse);
  });
}
