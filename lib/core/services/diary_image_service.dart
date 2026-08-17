import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'diary_image_store.dart';
import 'image_picker_support.dart';
import 'motion_photo_support.dart';

final diaryImageServiceProvider = Provider<DiaryImageService>((ref) {
  return DeviceDiaryImageService(
    imageStore: ref.watch(diaryImageStoreProvider),
  );
});

class StoredDiaryImage {
  const StoredDiaryImage({
    required this.filePath,
    required this.source,
    this.motionFilePath,
  });

  final String filePath;
  final String source;
  final String? motionFilePath;
}

abstract interface class DiaryImageService {
  Future<List<StoredDiaryImage>> pickAndStore({required int maxImages});
}

typedef PickDiaryImagePaths = Future<List<String>> Function(int maxImages);
typedef EncodeDiaryImageAsWebp =
    Future<bool> Function(String sourcePath, String destinationPath);
typedef LoadDiaryImageDirectory = Future<Directory> Function();

class DeviceDiaryImageService implements DiaryImageService {
  DeviceDiaryImageService({
    PickDiaryImagePaths? pickImagePaths,
    EncodeDiaryImageAsWebp? encodeWebp,
    LoadDiaryImageDirectory? loadImageDirectory,
    DiaryImageStore? imageStore,
    this._uuid = const Uuid(),
  }) : _pickImagePaths = pickImagePaths ?? pickGalleryImagePaths,
       _encodeWebp = encodeWebp ?? _encodeAsWebp,
       _loadImageDirectory =
           loadImageDirectory ??
           (imageStore == null
               ? _defaultImageDirectory
               : () async => imageStore.imageDirectory);

  final PickDiaryImagePaths _pickImagePaths;
  final EncodeDiaryImageAsWebp _encodeWebp;
  final LoadDiaryImageDirectory _loadImageDirectory;
  final Uuid _uuid;

  @override
  Future<List<StoredDiaryImage>> pickAndStore({required int maxImages}) async {
    if (maxImages < 1) {
      throw ArgumentError.value(maxImages, 'maxImages', 'must be positive');
    }
    final selectionLimit = imagePickerSelectionLimit(maxImages);
    final selections = imageSelectionsFromPaths(
      await _pickImagePaths(selectionLimit),
      maxImages: selectionLimit,
    );
    if (selections.isEmpty) return const [];

    final directory = await _loadImageDirectory();
    await directory.create(recursive: true);
    final destinationFiles = <File>[];
    final storedImages = <StoredDiaryImage>[];

    try {
      for (final selection in selections) {
        final imageId = _uuid.v4();
        final destinationPath = p.join(directory.path, '$imageId.webp');
        final motionPath = p.join(directory.path, motionPhotoFileName(imageId));
        final destinationFile = File(destinationPath);
        destinationFiles.add(destinationFile);
        final hasMotion = await storeMotionPhotoVideo(
          imagePath: selection.imagePath,
          pairedMotionPath: selection.motionPath,
          destinationPath: motionPath,
        );
        if (hasMotion) destinationFiles.add(File(motionPath));
        final encoded = await _encodeWebp(selection.imagePath, destinationPath);
        if (!encoded || !await destinationFile.exists()) {
          throw FileSystemException('WebP encoding did not create a file.');
        }
        storedImages.add(
          StoredDiaryImage(
            filePath: destinationPath,
            source: diaryImageSourceFromFileName(
              p.basename(destinationPath),
            )!.source,
            motionFilePath: hasMotion ? motionPath : null,
          ),
        );
      }
      return List.unmodifiable(storedImages);
    } on Object {
      for (final destinationFile in destinationFiles) {
        if (await destinationFile.exists()) {
          await destinationFile.delete();
        }
      }
      rethrow;
    }
  }

  static Future<bool> _encodeAsWebp(
    String sourcePath,
    String destinationPath,
  ) async {
    final extension = p.extension(sourcePath).toLowerCase();
    if (extension == '.gif' || extension == '.webp') {
      await File(sourcePath).copy(destinationPath);
      return true;
    }
    if (Platform.isWindows) {
      // flutter_image_compress has no Windows implementation. Flutter's
      // decoder reads the copied image by its file signature, so keeping the
      // original bytes preserves image import until native compression is
      // available on desktop.
      await File(sourcePath).copy(destinationPath);
      return true;
    }
    final result = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      destinationPath,
      format: CompressFormat.webp,
      quality: 88,
      keepExif: false,
      autoCorrectionAngle: true,
    );
    return result != null;
  }

  static Future<Directory> _defaultImageDirectory() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return Directory(p.join(documentsDirectory.path, 'images'));
  }
}
