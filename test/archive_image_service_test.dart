import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shadow_diary_mobile/core/services/archive_image_service.dart';
import 'package:shadow_diary_mobile/core/services/diary_image_store.dart';
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
    expect(images, everyElement(startsWith('diary-image://')));
    expect(images.toSet(), hasLength(2));
    final first = parseDiaryImageSource(images.first)!;
    expect(p.extension(first.fileName), '.webp');
    expect(
      await File(p.join(temporaryDirectory.path, first.fileName)).exists(),
      isTrue,
    );
  });

  test(
    'limits each picker request to nine images and rejects videos',
    () async {
      int? pickerLimit;
      final service = DeviceArchiveImageService(
        pickImagePaths: (maxImages) async {
          pickerLimit = maxImages;
          return const ['one.jpg', 'video.mp4', 'two.png'];
        },
        encodeWebp: (source, destination) async {
          await File(destination).writeAsString(source);
          return true;
        },
        loadImageDirectory: () async => temporaryDirectory,
      );

      final images = await service.pickAndStore(maxImages: 20);

      expect(pickerLimit, 9);
      expect(images, hasLength(2));
    },
  );

  test('keeps source bytes on Windows without native compression', () async {
    if (!Platform.isWindows) return;
    final source = File(p.join(temporaryDirectory.path, 'source.jpg'));
    final bytes = [5, 6, 7, 8, 9];
    await source.writeAsBytes(bytes);
    final service = DeviceArchiveImageService(
      pickImagePaths: (maxImages) async => [source.path],
      loadImageDirectory: () async => temporaryDirectory,
    );

    final images = await service.pickAndStore(maxImages: 1);
    final parsed = parseDiaryImageSource(images.single)!;

    expect(
      await File(
        p.join(temporaryDirectory.path, parsed.fileName),
      ).readAsBytes(),
      bytes,
    );
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

  test('delegates a batch of managed sources to image cleanup once', () async {
    final cleanup = _RecordingImageCleanup();
    final service = DeviceArchiveImageService(
      imageStore: DiaryImageStore(temporaryDirectory),
      imageCleanup: cleanup,
    );
    const first = 'diary-image://123e4567-e89b-42d3-a456-426614174000.webp';
    const second = 'diary-image://223e4567-e89b-42d3-a456-426614174001.webp';

    await service.deleteManagedImages([first, second, first]);

    expect(cleanup.calls, 1);
    expect(cleanup.candidates, {first, second});
  });
}

class _RecordingImageCleanup implements DiaryImageCleanup {
  int calls = 0;
  Set<String> candidates = const {};

  @override
  Future<void> cleanupUnreferenced({Iterable<String>? candidates}) async {
    calls++;
    this.candidates = candidates?.toSet() ?? const {};
  }
}
