import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shadow_diary_mobile/core/services/archive_image_service.dart';
import 'package:uuid/uuid.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'shadow-diary-archive-images-',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('stores selected images as uniquely named WebP files', () async {
    var pickerLimit = 0;
    final service = DeviceArchiveImageService(
      pickImagePaths: (maxImages) async {
        pickerLimit = maxImages;
        return ['one.jpg', 'two.jpg'];
      },
      encodeWebp: (source, destination) async {
        await File(destination).writeAsString(source);
        return true;
      },
      loadImageDirectory: () async => temporaryDirectory,
      uuid: const Uuid(),
    );

    final images = await service.pickAndStore(maxImages: 2);

    expect(pickerLimit, 2);
    expect(images, hasLength(2));
    expect(images.every((path) => p.extension(path) == '.webp'), isTrue);
    expect(images.toSet(), hasLength(2));
    expect(await File(images.first).exists(), isTrue);
  });

  test('cleans all attempted outputs when encoding fails', () async {
    var invocation = 0;
    final service = DeviceArchiveImageService(
      pickImagePaths: (maxImages) async => ['one.jpg', 'two.jpg'],
      encodeWebp: (source, destination) async {
        await File(destination).writeAsString(source);
        invocation++;
        if (invocation == 2) throw StateError('encoding failed');
        return true;
      },
      loadImageDirectory: () async => temporaryDirectory,
    );

    await expectLater(service.pickAndStore(maxImages: 2), throwsStateError);
    expect(temporaryDirectory.listSync(), isEmpty);
  });

  test('deletes only files inside the managed archive directory', () async {
    final managed = File(p.join(temporaryDirectory.path, 'managed.webp'));
    final outsideDirectory = await Directory.systemTemp.createTemp(
      'shadow-diary-outside-',
    );
    addTearDown(() async {
      if (await outsideDirectory.exists()) {
        await outsideDirectory.delete(recursive: true);
      }
    });
    final outside = File(p.join(outsideDirectory.path, 'outside.webp'));
    await managed.writeAsString('managed');
    await outside.writeAsString('outside');
    final service = DeviceArchiveImageService(
      loadImageDirectory: () async => temporaryDirectory,
    );

    await service.deleteManagedImages([managed.path, outside.path]);

    expect(await managed.exists(), isFalse);
    expect(await outside.exists(), isTrue);
  });
}
