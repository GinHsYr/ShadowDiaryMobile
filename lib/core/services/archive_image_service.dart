import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'diary_image_store.dart';

final archiveImageServiceProvider = Provider<ArchiveImageService>((ref) {
  return DeviceArchiveImageService(
    imageStore: ref.watch(diaryImageStoreProvider),
  );
});

abstract interface class ArchiveImageService {
  Future<List<String>> pickAndStore({required int maxImages});

  Future<void> deleteManagedImages(Iterable<String> paths);
}

typedef PickArchiveImagePaths = Future<List<String>> Function(int maxImages);
typedef EncodeArchiveImageAsWebp =
    Future<bool> Function(String sourcePath, String destinationPath);
typedef LoadArchiveImageDirectory = Future<Directory> Function();
typedef IsArchiveImageReferenced = Future<bool> Function(String source);

class DeviceArchiveImageService implements ArchiveImageService {
  DeviceArchiveImageService({
    PickArchiveImagePaths? pickImagePaths,
    EncodeArchiveImageAsWebp? encodeWebp,
    LoadArchiveImageDirectory? loadImageDirectory,
    DiaryImageStore? imageStore,
    this._isImageReferenced,
    this.uuid = const Uuid(),
  }) : _pickImagePaths = pickImagePaths ?? _pickImagesFromGallery,
       _encodeWebp = encodeWebp ?? _encodeAsWebp,
       _loadImageDirectory =
           loadImageDirectory ??
           (imageStore == null
               ? _defaultImageDirectory
               : () async => imageStore.imageDirectory),
       _imageStore = imageStore;

  final PickArchiveImagePaths _pickImagePaths;
  final EncodeArchiveImageAsWebp _encodeWebp;
  final LoadArchiveImageDirectory _loadImageDirectory;
  final DiaryImageStore? _imageStore;
  final IsArchiveImageReferenced? _isImageReferenced;
  final Uuid uuid;

  @override
  Future<List<String>> pickAndStore({required int maxImages}) async {
    if (maxImages < 1) {
      throw ArgumentError.value(maxImages, 'maxImages', 'must be positive');
    }
    final sourcePaths = (await _pickImagePaths(
      maxImages,
    )).take(maxImages).toList(growable: false);
    if (sourcePaths.isEmpty) return const [];

    final directory = await _loadImageDirectory();
    await directory.create(recursive: true);
    final storedPaths = <String>[];
    final attemptedPaths = <String>[];
    try {
      for (final sourcePath in sourcePaths) {
        final destinationPath = p.join(directory.path, '${uuid.v4()}.webp');
        attemptedPaths.add(destinationPath);
        final encoded = await _encodeWebp(sourcePath, destinationPath);
        if (!encoded || !await File(destinationPath).exists()) {
          throw FileSystemException('WebP encoding did not create a file.');
        }
        storedPaths.add(
          diaryImageSourceFromFileName(p.basename(destinationPath))!.source,
        );
      }
      return List.unmodifiable(storedPaths);
    } on Object {
      await _deleteExistingFiles(attemptedPaths);
      rethrow;
    }
  }

  @override
  Future<void> deleteManagedImages(Iterable<String> paths) async {
    final requestedSources = paths.where((path) => path.isNotEmpty).toSet();
    if (requestedSources.isEmpty) return;
    final Directory directory;
    try {
      directory = await _loadImageDirectory();
    } on Object {
      return;
    }
    final roots = <String>{p.normalize(p.absolute(directory.path))};
    final imageStore = _imageStore;
    if (imageStore?.documentsDirectory != null) {
      roots.add(p.normalize(p.absolute(imageStore!.thumbnailDirectory.path)));
    }
    final managedPaths = <String>{};
    for (final source in requestedSources) {
      try {
        if (await _isImageReferenced?.call(source) ?? false) continue;
      } on Object {
        continue;
      }
      final parsed = parseDiaryImageSource(source);
      final files = parsed != null && imageStore?.documentsDirectory != null
          ? await imageStore!.filesForImageId(parsed.imageId)
          : <File>[imageStore?.fileForSource(source) ?? File(source)];
      for (final file in files) {
        final path = p.normalize(p.absolute(file.path));
        if (roots.any((root) => p.isWithin(root, path))) {
          managedPaths.add(path);
        }
      }
    }
    await _deleteExistingFiles(managedPaths);
  }

  static Future<void> _deleteExistingFiles(Iterable<String> paths) async {
    for (final path in paths.toSet()) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // Database state is authoritative. Orphaned managed images can be
        // cleaned in a later maintenance pass.
      }
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
