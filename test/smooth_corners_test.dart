import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/theme/smooth_corners.dart';

void main() {
  test('uses one smoothness value for every corner primitive', () {
    expect(cornerSmoothing, 0.6);

    final shape = smoothRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    expect(shape.smoothness, cornerSmoothing);

    const materialShape = SmoothRoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    );
    expect(materialShape, isA<RoundedRectangleBorder>());
    expect(materialShape.smoothness, cornerSmoothing);

    const inputBorder = SmoothOutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    );
    expect(inputBorder.smoothness, cornerSmoothing);
  });

  test('decorations and clips keep the shared smoothing value', () {
    const decoration = SmoothBoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    );
    const clip = SmoothClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      child: SizedBox.shrink(),
    );

    expect(decoration.smoothness, cornerSmoothing);
    expect(clip.smoothness, cornerSmoothing);
  });
}
