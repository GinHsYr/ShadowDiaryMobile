import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'sync_models.dart';

class SyncAsset {
  const SyncAsset({
    required this.id,
    required this.path,
    required this.size,
    required this.sha256,
    this.mimeType = 'image/webp',
  });

  final String id;
  final String path;
  final int size;
  final String sha256;
  final String mimeType;

  Map<String, Object?> toManifestJson() => {
    'id': id,
    'size': size,
    'sha256': sha256,
    'mimeType': mimeType,
  };
}

class ReconcileResult {
  const ReconcileResult({
    required this.recordsForPeer,
    required this.conflicts,
    required this.appliedCount,
  });

  final List<SyncRecord> recordsForPeer;
  final List<SyncConflict> conflicts;
  final int appliedCount;
}

class SyncRepository {
  SyncRepository(
    this._appDatabase,
    this.deviceId, {
    Uuid? uuid,
    Future<Directory> Function()? loadSyncMediaDirectory,
  }) : _uuid = uuid ?? const Uuid(),
       _loadSyncMediaDirectory =
           loadSyncMediaDirectory ?? _defaultSyncMediaDirectory;

  final AppDatabase _appDatabase;
  final String deviceId;
  final Uuid _uuid;
  final Future<Directory> Function() _loadSyncMediaDirectory;
  final Sha256 _sha256 = Sha256();

  Database get _db => _appDatabase.database;

  Future<void> rememberPeer({required String id, required String name}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawInsert(
      '''
        INSERT INTO sync_devices(device_id, name, paired_at, last_seen_at)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(device_id) DO UPDATE SET
          name = excluded.name,
          last_seen_at = excluded.last_seen_at
      ''',
      [id, name, now, now],
    );
  }

  Future<void> markPeerSynced(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'sync_devices',
      {'last_seen_at': now, 'last_sync_at': now},
      where: 'device_id = ?',
      whereArgs: [id],
    );
  }

  Future<void> forgetPeer(String id) async {
    await _db.delete('sync_devices', where: 'device_id = ?', whereArgs: [id]);
    await _db.delete(
      'sync_conflicts',
      where: 'peer_device_id = ?',
      whereArgs: [id],
    );
  }

  Future<List<SyncRecord>> prepareSnapshot() async {
    final liveRecords = <String, SyncRecord>{};
    for (final record in await _readDiaryRecords()) {
      liveRecords[_recordKey(record.entityType, record.entityId)] = record;
    }
    for (final record in await _readArchiveRecords()) {
      liveRecords[_recordKey(record.entityType, record.entityId)] = record;
    }

    final metadataRows = await _db.query('sync_records');
    final metadata = <String, Map<String, Object?>>{
      for (final row in metadataRows)
        _recordKey(
          SyncEntityType.fromWireName(row['entity_type']! as String),
          row['entity_id']! as String,
        ): row,
    };
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = <SyncRecord>[];

    await _db.transaction((transaction) async {
      for (final entry in liveRecords.entries) {
        final source = entry.value;
        final stored = metadata[entry.key];
        final storedVector = stored == null
            ? const <String, int>{}
            : decodeVersionVector(stored['version_vector']! as String);
        final changed =
            stored == null ||
            stored['content_hash'] != source.contentHash ||
            stored['deleted_at'] != null;
        final vector = changed
            ? incrementVersionVector(storedVector, deviceId)
            : storedVector;
        final record = source.copyWith(
          versionVector: vector,
          modifiedAt: changed ? now : (stored['modified_at']! as int),
          clearDeletedAt: true,
        );
        await _upsertMetadata(transaction, record);
        result.add(record);
      }

      for (final entry in metadata.entries) {
        if (liveRecords.containsKey(entry.key)) continue;
        final row = entry.value;
        final type = SyncEntityType.fromWireName(row['entity_type']! as String);
        final existingDeletedAt = row['deleted_at'] as int?;
        final existingVector = decodeVersionVector(
          row['version_vector']! as String,
        );
        final record = SyncRecord(
          entityType: type,
          entityId: row['entity_id']! as String,
          versionVector: existingDeletedAt == null
              ? incrementVersionVector(existingVector, deviceId)
              : existingVector,
          contentHash: row['content_hash']! as String,
          modifiedAt: existingDeletedAt == null
              ? now
              : row['modified_at']! as int,
          deletedAt: existingDeletedAt ?? now,
        );
        if (existingDeletedAt == null) {
          await _upsertMetadata(transaction, record);
        }
        result.add(record);
      }
    });

    result.sort((a, b) {
      final typeOrder = a.entityType.wireName.compareTo(b.entityType.wireName);
      return typeOrder != 0 ? typeOrder : a.entityId.compareTo(b.entityId);
    });
    return List.unmodifiable(result);
  }

  Future<ReconcileResult> reconcileRemote(
    List<SyncRecord> remoteRecords,
    String peerDeviceId,
  ) async {
    final localRecords = {
      for (final record in await prepareSnapshot())
        _recordKey(record.entityType, record.entityId): record,
    };
    final recordsForPeer = <SyncRecord>[];
    final conflicts = <SyncConflict>[];
    var appliedCount = 0;

    for (final receivedRemote in remoteRecords) {
      final remote = await _normalizeRecordForSync(receivedRemote);
      final key = _recordKey(remote.entityType, remote.entityId);
      final local = localRecords.remove(key);
      if (local == null) {
        await _applyRemoteRecord(remote);
        appliedCount++;
        continue;
      }

      if (local.contentHash == remote.contentHash &&
          local.isDeleted == remote.isDeleted) {
        final merged = local.copyWith(
          versionVector: mergeVersionVectors(
            local.versionVector,
            remote.versionVector,
          ),
        );
        await _writeMetadata(merged);
        await _clearConflictFor(local.entityType, local.entityId, peerDeviceId);
        recordsForPeer.add(merged);
        continue;
      }
      if (local.isDeleted == remote.isDeleted &&
          _payloadsEquivalentForSync(
            local.entityType,
            local.payload,
            remote.payload,
          )) {
        final useRemote = _payloadUpdatedAt(remote) > _payloadUpdatedAt(local);
        final preferred = useRemote ? remote : local;
        final merged = preferred.copyWith(
          versionVector: mergeVersionVectors(
            local.versionVector,
            remote.versionVector,
          ),
        );
        if (useRemote) {
          await _applyRemoteRecord(merged);
          appliedCount++;
        } else {
          await _writeMetadata(merged);
        }
        await _clearConflictFor(local.entityType, local.entityId, peerDeviceId);
        recordsForPeer.add(merged);
        continue;
      }

      switch (compareVersionVectors(
        local.versionVector,
        remote.versionVector,
      )) {
        case VersionRelation.remoteDescends:
          await _applyRemoteRecord(remote);
          await _clearConflictFor(
            remote.entityType,
            remote.entityId,
            peerDeviceId,
          );
          appliedCount++;
        case VersionRelation.localDescends:
          recordsForPeer.add(local);
        case VersionRelation.equal || VersionRelation.concurrent:
          final conflict = await _storeConflict(
            local: local,
            remote: remote,
            peerDeviceId: peerDeviceId,
          );
          conflicts.add(conflict);
          recordsForPeer.add(local);
      }
    }

    recordsForPeer.addAll(localRecords.values);
    return ReconcileResult(
      recordsForPeer: List.unmodifiable(recordsForPeer),
      conflicts: List.unmodifiable(conflicts),
      appliedCount: appliedCount,
    );
  }

  Future<List<SyncConflict>> listConflicts() async {
    final rows = await _db.query('sync_conflicts', orderBy: 'created_at DESC');
    return rows.map(_conflictFromRow).toList(growable: false);
  }

  Future<void> resolveConflict(
    SyncConflict conflict,
    SyncConflictChoice choice,
  ) async {
    final local = SyncRecord(
      entityType: conflict.entityType,
      entityId: conflict.entityId,
      versionVector: conflict.localVector,
      contentHash: await _payloadHash(conflict.localPayload),
      modifiedAt: DateTime.now().millisecondsSinceEpoch,
      payload: conflict.localPayload,
      deletedAt: conflict.localPayload == null
          ? DateTime.now().millisecondsSinceEpoch
          : null,
    );
    final remote = SyncRecord(
      entityType: conflict.entityType,
      entityId: conflict.entityId,
      versionVector: conflict.remoteVector,
      contentHash: await _payloadHash(conflict.remotePayload),
      modifiedAt: DateTime.now().millisecondsSinceEpoch,
      payload: conflict.remotePayload,
      deletedAt: conflict.remotePayload == null
          ? DateTime.now().millisecondsSinceEpoch
          : null,
    );
    final mergedVector = incrementVersionVector(
      mergeVersionVectors(local.versionVector, remote.versionVector),
      deviceId,
    );

    switch (choice) {
      case SyncConflictChoice.keepLocal:
        await _applyRemoteRecord(local.copyWith(versionVector: mergedVector));
      case SyncConflictChoice.keepRemote:
        await _applyRemoteRecord(remote.copyWith(versionVector: mergedVector));
      case SyncConflictChoice.keepBoth:
        await _applyRemoteRecord(local.copyWith(versionVector: mergedVector));
        if (remote.payload != null) {
          final copyId = _uuid.v4();
          final titleKey = remote.entityType == SyncEntityType.diary
              ? 'title'
              : 'name';
          final payload = <String, Object?>{
            ...remote.payload!,
            'id': copyId,
            titleKey: '${remote.payload![titleKey] ?? ''} (冲突副本)',
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          };
          final copy = SyncRecord(
            entityType: remote.entityType,
            entityId: copyId,
            versionVector: {deviceId: 1},
            contentHash: await _payloadHash(payload),
            modifiedAt: DateTime.now().millisecondsSinceEpoch,
            payload: payload,
          );
          await _applyRemoteRecord(copy);
        }
    }
    await _db.delete(
      'sync_conflicts',
      where: 'id = ?',
      whereArgs: [conflict.id],
    );
  }

  Future<void> _clearConflictFor(
    SyncEntityType type,
    String entityId,
    String peerDeviceId,
  ) {
    return _db.delete(
      'sync_conflicts',
      where: 'entity_type = ? AND entity_id = ? AND peer_device_id = ?',
      whereArgs: [type.wireName, entityId, peerDeviceId],
    );
  }

  Future<List<SyncAsset>> collectAssets(List<SyncRecord> records) async {
    final pathsById = <String, String>{};
    final referencedIds = <String>{
      for (final record in records)
        if (record.payload != null) ..._canonicalAssetIds(record.payload!),
    };
    final candidates = <String>[];
    final diaryRows = await _db.query('diary_entries', columns: ['content']);
    for (final row in diaryRows) {
      candidates.addAll(_extractLocalImageSources(row['content'] as String?));
    }
    final archiveRows = await _db.query(
      'archives',
      columns: ['main_image', 'images'],
    );
    for (final row in archiveRows) {
      if (row['main_image'] case final String value) candidates.add(value);
      candidates.addAll(_decodeStringList(row['images'] as String?));
    }
    for (final source in candidates) {
      final localPath = _localPathFromSource(source);
      final assetId = _assetIdFromSource(source);
      if (localPath != null &&
          assetId != null &&
          referencedIds.contains(assetId)) {
        pathsById.putIfAbsent(assetId, () => localPath);
      }
    }

    final assets = <SyncAsset>[];
    for (final entry in pathsById.entries) {
      final file = File(entry.value);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final digest = await _sha256.hash(bytes);
      assets.add(
        SyncAsset(
          id: entry.key,
          path: file.path,
          size: bytes.length,
          sha256: _hex(digest.bytes),
          mimeType: _syncAssetMimeType(entry.key),
        ),
      );
    }
    return List.unmodifiable(assets);
  }

  Future<bool> hasAsset(String id, String expectedHash) async {
    final directory = await _loadSyncMediaDirectory();
    final file = File(p.join(directory.path, _safeAssetFileName(id)));
    if (!await file.exists()) return false;
    final digest = await _sha256.hash(await file.readAsBytes());
    return _hex(digest.bytes) == expectedHash.toLowerCase();
  }

  Future<void> storeAsset(
    String id,
    List<int> bytes,
    String expectedHash,
  ) async {
    if (bytes.length > 32 * 1024 * 1024) {
      throw const FormatException('Sync asset exceeds 32 MiB.');
    }
    final actual = _hex((await _sha256.hash(bytes)).bytes);
    if (actual != expectedHash.toLowerCase()) {
      throw const FormatException('Sync asset hash mismatch.');
    }
    final directory = await _loadSyncMediaDirectory();
    await directory.create(recursive: true);
    final target = File(p.join(directory.path, _safeAssetFileName(id)));
    final temporary = File('${target.path}.part');
    await temporary.writeAsBytes(bytes, flush: true);
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }

  Future<List<SyncRecord>> _readDiaryRecords() async {
    final rows = await _db.rawQuery('''
      SELECT e.id, e.title, e.content, e.plain_content, e.mood, e.weather,
             e.created_at, e.updated_at,
             GROUP_CONCAT(t.name, char(31)) AS tags
      FROM diary_entries e
      LEFT JOIN diary_tags dt ON dt.diary_id = e.id
      LEFT JOIN tags t ON t.id = dt.tag_id
      GROUP BY e.id
      ORDER BY e.id
    ''');
    final records = <SyncRecord>[];
    for (final row in rows) {
      final createdAt = row['created_at']! as int;
      final date = DateTime.fromMillisecondsSinceEpoch(createdAt);
      final calendarDate =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final rawTags = row['tags'] as String?;
      final tags =
          rawTags == null ? <String>[] : rawTags.split(String.fromCharCode(31))
            ..sort();
      final payload = <String, Object?>{
        'id': row['id']! as String,
        'title': row['title']! as String,
        'content': _canonicalizeMediaSources(row['content']! as String),
        'plainContent': row['plain_content']! as String,
        'mood': row['mood']! as String,
        'weather': row['weather'] as String?,
        'calendarDate': calendarDate,
        'createdAt': DateTime.utc(
          date.year,
          date.month,
          date.day,
        ).millisecondsSinceEpoch,
        'updatedAt': row['updated_at']! as int,
        'tags': tags,
      };
      records.add(
        SyncRecord(
          entityType: SyncEntityType.diary,
          entityId: row['id']! as String,
          versionVector: const {},
          contentHash: await _payloadHash(payload),
          modifiedAt: row['updated_at']! as int,
          payload: payload,
        ),
      );
    }
    return records;
  }

  Future<List<SyncRecord>> _readArchiveRecords() async {
    final rows = await _db.query('archives', orderBy: 'id');
    final records = <SyncRecord>[];
    for (final row in rows) {
      final aliases = (row['alias'] as String? ?? '')
          .split(RegExp(r'[,，;；\r\n]+'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      final rawImages = _decodeStringList(row['images'] as String?);
      final payload = <String, Object?>{
        'id': row['id']! as String,
        'name': row['name']! as String,
        'aliases': aliases,
        'description': row['description'] as String?,
        'type': row['type']! as String,
        'mainImage': _canonicalizeOptionalSource(row['main_image'] as String?),
        'images': rawImages
            .map(_canonicalizeOptionalSource)
            .whereType<String>()
            .toList(growable: false),
        'createdAt': row['created_at']! as int,
        'updatedAt': row['updated_at']! as int,
      };
      records.add(
        SyncRecord(
          entityType: SyncEntityType.archive,
          entityId: row['id']! as String,
          versionVector: const {},
          contentHash: await _payloadHash(payload),
          modifiedAt: row['updated_at']! as int,
          payload: payload,
        ),
      );
    }
    return records;
  }

  Future<void> _applyRemoteRecord(SyncRecord record) async {
    await _db.transaction((transaction) async {
      if (record.isDeleted || record.payload == null) {
        await transaction.delete(
          record.entityType == SyncEntityType.diary
              ? 'diary_entries'
              : 'archives',
          where: 'id = ?',
          whereArgs: [record.entityId],
        );
      } else if (record.entityType == SyncEntityType.diary) {
        await _applyDiary(transaction, record.payload!);
      } else {
        await _applyArchive(transaction, record.payload!);
      }
      await _upsertMetadata(transaction, record);
    });
  }

  Future<void> _applyDiary(
    DatabaseExecutor transaction,
    Map<String, Object?> payload,
  ) async {
    final id = payload['id']! as String;
    final content = await _localizeMediaSources(payload['content']! as String);
    await transaction.insert('diary_entries', {
      'id': id,
      'title': payload['title'] as String? ?? '',
      'content': content,
      'plain_content': payload['plainContent'] as String? ?? '',
      'mood': payload['mood'] as String? ?? 'calm',
      'weather': payload['weather'] as String?,
      'created_at': _localDiaryTimestamp(payload),
      'updated_at': (payload['updatedAt']! as num).toInt(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await transaction.delete(
      'diary_tags',
      where: 'diary_id = ?',
      whereArgs: [id],
    );
    final tags = (payload['tags'] as List?)?.whereType<String>() ?? const [];
    for (final tag in tags) {
      await transaction.insert('tags', {
        'name': tag,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final tagRows = await transaction.query(
        'tags',
        columns: ['id'],
        where: 'name = ?',
        whereArgs: [tag],
        limit: 1,
      );
      if (tagRows.isNotEmpty) {
        await transaction.insert('diary_tags', {
          'diary_id': id,
          'tag_id': tagRows.single['id'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  Future<void> _applyArchive(
    DatabaseExecutor transaction,
    Map<String, Object?> payload,
  ) async {
    final aliases =
        (payload['aliases'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final rawImages = payload['images'] is List
        ? (payload['images']! as List).whereType<String>()
        : const <String>[];
    final localizedImages = <String>[];
    for (final image in rawImages) {
      final canonical = _canonicalizeOptionalSource(image);
      if (canonical != null) {
        localizedImages.add(await _localizeMediaSources(canonical));
      }
    }
    final mainImage = _canonicalizeOptionalSource(
      payload['mainImage'] is String ? payload['mainImage']! as String : null,
    );
    await transaction.insert('archives', {
      'id': payload['id']! as String,
      'name': payload['name'] as String? ?? '',
      'alias': aliases.isEmpty ? null : aliases.join(', '),
      'description': payload['description'] as String?,
      'type': payload['type'] as String? ?? 'other',
      'main_image': mainImage == null
          ? null
          : await _localizeMediaSources(mainImage),
      'images': jsonEncode(localizedImages),
      'created_at': (payload['createdAt']! as num).toInt(),
      'updated_at': (payload['updatedAt']! as num).toInt(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<SyncConflict> _storeConflict({
    required SyncRecord local,
    required SyncRecord remote,
    required String peerDeviceId,
  }) async {
    final id = _uuid.v4();
    final createdAt = DateTime.now();
    await _clearConflictFor(local.entityType, local.entityId, peerDeviceId);
    await _db.insert('sync_conflicts', {
      'id': id,
      'entity_type': local.entityType.wireName,
      'entity_id': local.entityId,
      'peer_device_id': peerDeviceId,
      'local_payload': local.payload == null ? null : jsonEncode(local.payload),
      'remote_payload': remote.payload == null
          ? null
          : jsonEncode(remote.payload),
      'local_vector': encodeVersionVector(local.versionVector),
      'remote_vector': encodeVersionVector(remote.versionVector),
      'created_at': createdAt.millisecondsSinceEpoch,
    });
    return SyncConflict(
      id: id,
      entityType: local.entityType,
      entityId: local.entityId,
      peerDeviceId: peerDeviceId,
      localPayload: local.payload,
      remotePayload: remote.payload,
      localVector: local.versionVector,
      remoteVector: remote.versionVector,
      createdAt: createdAt,
    );
  }

  SyncConflict _conflictFromRow(Map<String, Object?> row) {
    Map<String, Object?>? decodePayload(Object? value) {
      if (value is! String) return null;
      final decoded = jsonDecode(value);
      return decoded is Map
          ? decoded.map((key, item) => MapEntry(key.toString(), item))
          : null;
    }

    return SyncConflict(
      id: row['id']! as String,
      entityType: SyncEntityType.fromWireName(row['entity_type']! as String),
      entityId: row['entity_id']! as String,
      peerDeviceId: row['peer_device_id']! as String,
      localPayload: decodePayload(row['local_payload']),
      remotePayload: decodePayload(row['remote_payload']),
      localVector: decodeVersionVector(row['local_vector']! as String),
      remoteVector: decodeVersionVector(row['remote_vector']! as String),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
    );
  }

  Future<void> _writeMetadata(SyncRecord record) {
    return _db.transaction(
      (transaction) => _upsertMetadata(transaction, record),
    );
  }

  Future<void> _upsertMetadata(
    DatabaseExecutor transaction,
    SyncRecord record,
  ) async {
    await transaction.insert('sync_records', {
      'entity_type': record.entityType.wireName,
      'entity_id': record.entityId,
      'version_vector': encodeVersionVector(record.versionVector),
      'content_hash': record.contentHash,
      'deleted_at': record.deletedAt,
      'modified_at': record.modifiedAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> _payloadHash(Map<String, Object?>? payload) async {
    if (payload == null) return '';
    final digest = await _sha256.hash(utf8.encode(_stableJson(payload)));
    return _hex(digest.bytes);
  }

  Future<SyncRecord> _normalizeRecordForSync(SyncRecord record) async {
    final original = record.payload;
    if (original == null) return record;
    final normalized = _normalizePayloadForSync(record.entityType, original)!;
    if (_stableJson(original) == _stableJson(normalized)) return record;
    return record.copyWith(
      payload: normalized,
      contentHash: await _payloadHash(normalized),
    );
  }

  bool _payloadsEquivalentForSync(
    SyncEntityType entityType,
    Map<String, Object?>? local,
    Map<String, Object?>? remote,
  ) {
    if (local == null || remote == null) return local == remote;
    final localContent = _normalizePayloadForSync(entityType, local)!
      ..remove('updatedAt');
    final remoteContent = _normalizePayloadForSync(entityType, remote)!
      ..remove('updatedAt');
    return _stableJson(localContent) == _stableJson(remoteContent);
  }

  Map<String, Object?>? _normalizePayloadForSync(
    SyncEntityType entityType,
    Map<String, Object?>? payload,
  ) {
    if (payload == null) return null;
    final normalized = Map<String, Object?>.of(payload);
    if (entityType != SyncEntityType.archive) return normalized;

    normalized['mainImage'] = _canonicalizeOptionalSource(
      payload['mainImage'] is String ? payload['mainImage']! as String : null,
    );
    normalized['images'] = payload['images'] is List
        ? (payload['images']! as List)
              .whereType<String>()
              .map(_canonicalizeOptionalSource)
              .whereType<String>()
              .toList(growable: false)
        : const <String>[];
    return normalized;
  }

  int _payloadUpdatedAt(SyncRecord record) {
    final value = record.payload?['updatedAt'];
    return value is num ? value.toInt() : record.modifiedAt;
  }

  String _stableJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return '{${keys.map((key) => '${jsonEncode(key)}:${_stableJson(value[key])}').join(',')}}';
    }
    if (value is List) {
      return '[${value.map(_stableJson).join(',')}]';
    }
    return jsonEncode(value);
  }

  String _canonicalizeMediaSources(String value) {
    return value.replaceAllMapped(
      RegExp(
        r'''(?:file:(?://)?[^"'<>\s]*|[A-Za-z]:[\\/][^"'<>\s]*)'''
        r'([a-fA-F0-9-]{36}(?:_thumb\.webp|\.(?:webp|png|jpe?g)))',
        caseSensitive: false,
      ),
      (match) => 'diary-image://${match.group(1)!.toLowerCase()}',
    );
  }

  String? _canonicalizeOptionalSource(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    final id = _assetIdFromSource(normalized);
    return id == null ? normalized : 'diary-image://$id';
  }

  Iterable<String> _extractLocalImageSources(String? content) sync* {
    if (content == null || content.isEmpty) return;
    final matches = RegExp(
      r'''(?:src|data-src)=["']([^"']+)["']''',
      caseSensitive: false,
    ).allMatches(content);
    for (final match in matches) {
      final source = match.group(1);
      if (source != null) yield source;
    }
  }

  Iterable<String> _canonicalAssetIds(Map<String, Object?> payload) sync* {
    final values = <String>[];
    if (payload['content'] case final String content) {
      values.addAll(_extractLocalImageSources(content));
    }
    if (payload['mainImage'] case final String mainImage) values.add(mainImage);
    if (payload['images'] case final List images) {
      values.addAll(images.whereType<String>());
    }
    for (final value in values) {
      final matches = RegExp(
        r'diary-image://([a-f0-9-]{36}(?:_thumb\.webp|\.(?:webp|png|jpe?g)))',
        caseSensitive: false,
      ).allMatches(value);
      for (final match in matches) {
        yield match.group(1)!.toLowerCase();
      }
    }
  }

  String? _assetIdFromSource(String source) {
    const assetScheme = 'diary-image://';
    final normalized = source.trim();
    final filename = normalized.toLowerCase().startsWith(assetScheme)
        ? normalized.substring(assetScheme.length).toLowerCase()
        : normalized.replaceAll('\\', '/').split('/').last.toLowerCase();
    return RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}(?:_thumb\.webp|\.(?:webp|png|jpe?g))$',
        ).hasMatch(filename)
        ? filename
        : null;
  }

  String? _localPathFromSource(String source) {
    if (RegExp(r'^[A-Za-z]:[\\/]').hasMatch(source)) return source;
    final uri = Uri.tryParse(source);
    if (uri?.scheme == 'file') {
      try {
        return uri!.toFilePath();
      } on Object {
        return null;
      }
    }
    if (uri == null || uri.scheme.isEmpty) return source;
    return null;
  }

  Future<String> _localizeMediaSources(String value) async {
    final directory = await _loadSyncMediaDirectory();
    await directory.create(recursive: true);
    return value.replaceAllMapped(
      RegExp(
        r'diary-image://([a-f0-9-]{36}(?:_thumb\.webp|\.(?:webp|png|jpe?g)))',
        caseSensitive: false,
      ),
      (match) => Uri.file(
        p.join(directory.path, _safeAssetFileName(match.group(1)!)),
      ).toString(),
    );
  }

  String _safeAssetFileName(String id) {
    final normalized = id.toLowerCase();
    if (!RegExp(
      r'^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}(?:_thumb\.webp|\.(?:webp|png|jpe?g))$',
    ).hasMatch(normalized)) {
      throw const FormatException('Invalid sync asset identifier.');
    }
    return normalized;
  }

  String _syncAssetMimeType(String id) {
    return switch (p.extension(id).toLowerCase()) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      _ => 'image/webp',
    };
  }

  List<String> _decodeStringList(String? value) {
    if (value == null || value.isEmpty) return const [];
    try {
      final decoded = jsonDecode(value);
      return decoded is List ? decoded.whereType<String>().toList() : const [];
    } on FormatException {
      return const [];
    }
  }

  int _localDiaryTimestamp(Map<String, Object?> payload) {
    final calendarDate = payload['calendarDate'] as String?;
    final parts = calendarDate?.split('-');
    if (parts != null && parts.length == 3) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year != null && month != null && day != null) {
        final localNoon = DateTime(year, month, day, 12);
        if (localNoon.year == year &&
            localNoon.month == month &&
            localNoon.day == day) {
          return localNoon.millisecondsSinceEpoch;
        }
      }
    }
    return (payload['createdAt']! as num).toInt();
  }

  static String _recordKey(SyncEntityType type, String id) {
    return '${type.wireName}:$id';
  }

  static String _hex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<Directory> _defaultSyncMediaDirectory() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return Directory(p.join(documentsDirectory.path, 'media', 'sync'));
  }
}
