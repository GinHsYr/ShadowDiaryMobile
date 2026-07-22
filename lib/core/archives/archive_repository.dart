import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'archive.dart';

final archiveRepositoryProvider = Provider<ArchiveRepository>((ref) {
  throw StateError('ArchiveRepository must be overridden at bootstrap.');
});

final archiveListProvider = FutureProvider<List<Archive>>((ref) {
  return ref.watch(archiveRepositoryProvider).listArchives();
});

abstract interface class ArchiveRepository {
  Future<List<Archive>> listArchives();

  Future<Archive?> findById(String id);

  Future<void> save(Archive archive);

  Future<void> delete(String id);
}

class SqliteArchiveRepository implements ArchiveRepository {
  SqliteArchiveRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<Archive>> listArchives() async {
    final rows = await _appDatabase.database.query('archives');
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<Archive?> findById(String id) async {
    final rows = await _appDatabase.database.query(
      'archives',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  @override
  Future<void> save(Archive archive) async {
    final name = archive.name.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(
        archive.name,
        'archive.name',
        'must not be empty',
      );
    }
    final alias = _normalizeAliases(archive.alias);
    final description = archive.description?.trim();
    final mainImage = _nullIfEmpty(archive.mainImage);
    final images = archive.images
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty && path != mainImage)
        .toSet()
        .toList(growable: false);
    final values = <String, Object?>{
      'name': name,
      'alias': alias,
      'description': description == null || description.isEmpty
          ? null
          : description,
      'type': archive.type.databaseValue,
      'main_image': mainImage,
      'images': images.isEmpty ? null : jsonEncode(images),
      'created_at': archive.createdAt.millisecondsSinceEpoch,
      'updated_at': archive.updatedAt.millisecondsSinceEpoch,
    };

    await _appDatabase.database.transaction((transaction) async {
      final updated = await transaction.update(
        'archives',
        values,
        where: 'id = ?',
        whereArgs: [archive.id],
      );
      if (updated == 0) {
        await transaction.insert('archives', {'id': archive.id, ...values});
      }
    });
  }

  @override
  Future<void> delete(String id) async {
    await _appDatabase.database.delete(
      'archives',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Archive _fromRow(Map<String, Object?> row) {
    return Archive(
      id: row['id']! as String,
      name: row['name']! as String,
      alias: row['alias'] as String?,
      description: row['description'] as String?,
      type: ArchiveType.fromDatabase(row['type']! as String),
      mainImage: row['main_image'] as String?,
      images: _decodeImages(row['images']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
    );
  }
}

String? _normalizeAliases(String? value) {
  if (value == null) return null;
  final aliases = value
      .split(RegExp(r'[,，]'))
      .map((alias) => alias.trim())
      .where((alias) => alias.isNotEmpty)
      .toSet()
      .toList(growable: false);
  return aliases.isEmpty ? null : aliases.join(',');
}

String? _nullIfEmpty(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

List<String> _decodeImages(Object? value) {
  if (value is! String || value.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(value);
    if (decoded is! List<Object?>) return const [];
    return decoded
        .whereType<String>()
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toSet()
        .toList(growable: false);
  } on FormatException {
    return const [];
  }
}
