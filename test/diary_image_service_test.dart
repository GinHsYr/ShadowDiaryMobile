import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/services/diary_image_service.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'shadow_diary_images_',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('does not create a file when gallery selection is cancelled', () async {
    var loadedDirectory = false;
    final service = DeviceDiaryImageService(
      pickImagePaths: (maxImages) async => const [],
      loadImageDirectory: () async {
        loadedDirectory = true;
        return temporaryDirectory;
      },
    );

    expect(await service.pickAndStore(maxImages: 9), isEmpty);
    expect(loadedDirectory, isFalse);
    expect(await temporaryDirectory.list().toList(), isEmpty);
  });

  test('stores all selected images with WebP extensions', () async {
    final encodedDestinations = <String>[];
    int? pickerLimit;
    final service = DeviceDiaryImageService(
      pickImagePaths: (maxImages) async {
        pickerLimit = maxImages;
        return ['first.jpg', 'second.png'];
      },
      loadImageDirectory: () async => temporaryDirectory,
      encodeWebp: (sourcePath, destinationPath) async {
        encodedDestinations.add(destinationPath);
        await File(destinationPath).writeAsBytes([1, 2, 3]);
        return true;
      },
    );

    final images = await service.pickAndStore(maxImages: 9);

    expect(pickerLimit, 9);
    expect(images, hasLength(2));
    expect(encodedDestinations, everyElement(endsWith('.webp')));
    for (var index = 0; index < images.length; index++) {
      expect(images[index].filePath, encodedDestinations[index]);
      expect(images[index].uri, Uri.file(encodedDestinations[index]));
      expect(await File(images[index].filePath).exists(), isTrue);
    }
  });

  test('caps a picker response at the requested image count', () async {
    var encodedCount = 0;
    final service = DeviceDiaryImageService(
      pickImagePaths: (maxImages) async =>
          List.generate(12, (index) => 'selected-$index.jpg'),
      loadImageDirectory: () async => temporaryDirectory,
      encodeWebp: (sourcePath, destinationPath) async {
        encodedCount++;
        await File(destinationPath).writeAsBytes([1]);
        return true;
      },
    );

    final images = await service.pickAndStore(maxImages: 9);

    expect(images, hasLength(9));
    expect(encodedCount, 9);
  });

  test('removes the whole batch when one WebP encoding fails', () async {
    var encodedCount = 0;
    final service = DeviceDiaryImageService(
      pickImagePaths: (maxImages) async => ['first.jpg', 'second.jpg'],
      loadImageDirectory: () async => temporaryDirectory,
      encodeWebp: (sourcePath, destinationPath) async {
        encodedCount++;
        await File(destinationPath).writeAsBytes([1, 2, 3]);
        if (encodedCount == 2) throw StateError('encoding failed');
        return true;
      },
    );

    await expectLater(service.pickAndStore(maxImages: 9), throwsStateError);
    expect(await temporaryDirectory.list().toList(), isEmpty);
  });
}
