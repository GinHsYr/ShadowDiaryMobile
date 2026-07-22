import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

final archiveImageServiceProvider = Provider<ArchiveImageService>((ref) {
  return DeviceArchiveImageService();
});

abstract interface class ArchiveImageService {
  Future<List<String>> pickAndStore({required int maxImages});

  Future<void> deleteManagedImages(Iterable<String> paths);
}

typedef PickArchiveImagePaths = Future<List<String>> Function(int maxImages);
typedef EncodeArchiveImageAsWebp =
    Future<bool> Function(String sourcePath, String destinationPath);
typedef LoadArchiveImageDirectory = Future<Directory> Function();

class DeviceArchiveImageService implements ArchiveImageService {
  DeviceArchiveImageService({
    PickArchiveImagePaths? pickImagePaths,
    EncodeArchiveImageAsWebp? encodeWebp,
    LoadArchiveImageDirectory? loadImageDirectory,
    this.uuid = const Uuid(),
  }) : _pickImagePaths = pickImagePaths ?? _pickImagesFromGallery,
       _encodeWebp = encodeWebp ?? _encodeAsWebp,
       _loadImageDirectory = loadImageDirectory ?? _defaultImageDirectory;

  final PickArchiveImagePaths _pickImagePaths;
  final EncodeArchiveImageAsWebp _encodeWebp;
  final LoadArchiveImageDirectory _loadImageDirectory;
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
        storedPaths.add(destinationPath);
      }
      return List.unmodifiable(storedPaths);
    } on Object {
      await _deleteExistingFiles(attemptedPaths);
      rethrow;
    }
  }

  @override
  Future<void> deleteManagedImages(Iterable<String> paths) async {
    final requestedPaths = paths.where((path) => path.isNotEmpty).toSet();
    if (requestedPaths.isEmpty) return;
    final Directory directory;
    try {
      directory = await _loadImageDirectory();
    } on Object {
      return;
    }
    final root = p.normalize(p.absolute(directory.path));
    final managedPaths = requestedPaths
        .map((path) => p.normalize(p.absolute(path)))
        .where((path) => p.isWithin(root, path));
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
    return Directory(p.join(documentsDirectory.path, 'media', 'archive'));
  }
}
