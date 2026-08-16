import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'diary_image_store.dart';

final diaryImageServiceProvider = Provider<DiaryImageService>((ref) {
  return DeviceDiaryImageService(
    imageStore: ref.watch(diaryImageStoreProvider),
  );
});

class StoredDiaryImage {
  const StoredDiaryImage({required this.filePath, required this.source});

  final String filePath;
  final String source;
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
  }) : _pickImagePaths = pickImagePaths ?? _pickImagesFromGallery,
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
    final sourcePaths = (await _pickImagePaths(
      maxImages,
    )).take(maxImages).toList(growable: false);
    if (sourcePaths.isEmpty) return const [];

    final directory = await _loadImageDirectory();
    await directory.create(recursive: true);
    final destinationFiles = <File>[];
    final storedImages = <StoredDiaryImage>[];

    try {
      for (final sourcePath in sourcePaths) {
        final destinationPath = p.join(directory.path, '${_uuid.v4()}.webp');
        final destinationFile = File(destinationPath);
        destinationFiles.add(destinationFile);
        final encoded = await _encodeWebp(sourcePath, destinationPath);
        if (!encoded || !await destinationFile.exists()) {
          throw FileSystemException('WebP encoding did not create a file.');
        }
        storedImages.add(
          StoredDiaryImage(
            filePath: destinationPath,
            source: diaryImageSourceFromFileName(
              p.basename(destinationPath),
            )!.source,
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

  static Future<List<String>> _pickImagesFromGallery(int maxImages) async {
    final images = await ImagePicker().pickMultiImage(limit: maxImages);
    return images.map((image) => image.path).toList(growable: false);
  }

  static Future<bool> _encodeAsWebp(
    String sourcePath,
    String destinationPath,
  ) async {
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
