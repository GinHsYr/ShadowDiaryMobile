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
}
