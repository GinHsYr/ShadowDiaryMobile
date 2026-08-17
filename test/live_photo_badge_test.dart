import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/widgets/live_photo_badge.dart';

void main() {
  test(
    'refreshes the bounded detection cache when a motion file appears',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'shadow-live-photo-',
      );
      addTearDown(() => directory.delete(recursive: true));

      final image = File('${directory.path}/image.jpg');
      final motion = File('${directory.path}/image_motion.mp4');
      await image.writeAsBytes(const <int>[0, 1, 2]);

      expect(await isLivePhotoFile(image, motionFile: motion), isFalse);
      await motion.writeAsBytes(const <int>[3, 4, 5]);
      expect(await isLivePhotoFile(image, motionFile: motion), isTrue);
    },
  );
}
