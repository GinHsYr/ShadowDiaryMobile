import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'sync_crypto.dart';
import 'sync_models.dart';
import 'sync_repository.dart';
import 'sync_secure_store.dart';

class SyncClientResult {
  const SyncClientResult({
    required this.appliedRecords,
    required this.conflicts,
    required this.transferredBytes,
  });

  final int appliedRecords;
  final int conflicts;
  final int transferredBytes;
}

typedef SyncProgressCallback = void Function(SyncProgress progress);

class ShadowSyncClient {
  ShadowSyncClient({
    required this.deviceId,
    required this.repository,
    required this.secureStore,
    SyncCrypto? crypto,
    WebSocketChannel Function(Uri endpoint)? connectChannel,
  }) : _crypto = crypto ?? SyncCrypto(),
       _connectChannel = connectChannel ?? _defaultConnect;

  static const _protocol = 'shadowdiary-sync-v1';
  static const _chunkSize = 192 * 1024;

  final String deviceId;
  final SyncRepository repository;
  final SyncSecureStore secureStore;
  final SyncCrypto _crypto;
  final WebSocketChannel Function(Uri endpoint) _connectChannel;

  Future<PairedPeerSecret> pair(SyncPeer peer, String pairingCode) async {
    final normalizedCode = pairingCode.replaceAll(RegExp(r'\D'), '');
    if (normalizedCode.length != 6) {
      throw const FormatException('Pairing code must contain six digits.');
    }

    final ephemeral = await _crypto.newEphemeralKeyPair();
    final clientPublic = base64Encode(ephemeral.publicKey);
    final connection = await _open(peer);
    try {
      connection.sendPlain({
        'kind': 'hello',
        'protocol': 1,
        'mode': 'pair',
        'deviceId': deviceId,
        'deviceName': 'ShadowDiary Android',
        'publicKey': clientPublic,
      });
      final challenge = await connection.nextPlain();
      _expectKind(challenge, 'pairChallenge');
      final serverId = challenge['serverId']! as String;
      if (serverId != peer.deviceId) {
        throw const FormatException('Discovered peer identity changed.');
      }
      final nonceText = challenge['nonce']! as String;
      final serverPublicText = challenge['publicKey']! as String;
      final pairingKey = await _crypto.derivePairingKey(
        keyPair: ephemeral.keyPair,
        remotePublicKey: base64Decode(serverPublicText),
        pairingCode: normalizedCode,
        nonce: base64Decode(nonceText),
      );
      final transcript =
          '$deviceId|$serverId|$nonceText|$clientPublic|$serverPublicText';
      connection.sendPlain({
        'kind': 'pairResponse',
        'proof': await _crypto.proof(
          key: pairingKey,
          value: 'pair-client|$transcript',
        ),
      });
      final cipher = SyncSessionCipher(pairingKey);
      final accepted = await connection.nextEncrypted(cipher);
      _expectKind(accepted, 'pairAccepted');
      final secret = base64Decode(accepted['sharedSecret']! as String);
      if (secret.length != 32) {
        throw const FormatException('Invalid paired-device secret.');
      }
      final stored = PairedPeerSecret(
        deviceId: serverId,
        name: accepted['serverName'] as String? ?? peer.name,
        secret: secret,
      );
      await secureStore.savePeerSecret(stored);
      await repository.rememberPeer(id: stored.deviceId, name: stored.name);
      return stored;
    } finally {
      await connection.close();
    }
  }

  Future<SyncClientResult> synchronize(
    SyncPeer peer,
    PairedPeerSecret pairedPeer, {
    SyncProgressCallback? onProgress,
  }) async {
    if (peer.deviceId != pairedPeer.deviceId) {
      throw const FormatException('Paired peer identity mismatch.');
    }
    final connection = await _open(peer);
    var transferredBytes = 0;
    try {
      connection.sendPlain({
        'kind': 'hello',
        'protocol': 1,
        'mode': 'paired',
        'deviceId': deviceId,
        'deviceName': 'ShadowDiary Android',
      });
      final challenge = await connection.nextPlain();
      _expectKind(challenge, 'authChallenge');
      final nonceText = challenge['nonce']! as String;
      final serverId = challenge['serverId']! as String;
      if (serverId != pairedPeer.deviceId) {
        throw const FormatException('Authenticated peer identity mismatch.');
      }
      connection.sendPlain({
        'kind': 'authResponse',
        'proof': await _crypto.proof(
          key: pairedPeer.secret,
          value: 'auth-client|$nonceText|$deviceId|$serverId',
        ),
      });
      final accepted = await connection.nextPlain();
      _expectKind(accepted, 'authAccepted');
      final validServer = await _crypto.verifyProof(
        key: pairedPeer.secret,
        value: 'auth-server|$nonceText|$deviceId|$serverId',
        encodedProof: accepted['proof']! as String,
      );
      if (!validServer) {
        throw const FormatException('Server authentication failed.');
      }
      await repository.rememberPeer(
        id: pairedPeer.deviceId,
        name: pairedPeer.name,
      );
      final sessionKey = await _crypto.deriveSessionKey(
        sharedSecret: pairedPeer.secret,
        nonce: base64Decode(nonceText),
      );
      final cipher = SyncSessionCipher(sessionKey);
      final records = await repository.prepareSnapshot();
      final assets = await repository.collectAssets(records);
      final totalBytes = assets.fold<int>(0, (sum, asset) => sum + asset.size);
      onProgress?.call(
        SyncProgress(totalRecords: records.length, totalBytes: totalBytes),
      );
      await connection.sendEncrypted(cipher, {
        'kind': 'syncSnapshot',
        'records': records.map((record) => record.toJson()).toList(),
        'assets': assets.map((asset) => asset.toManifestJson()).toList(),
      });

      final plan = await connection.nextEncrypted(cipher);
      _expectKind(plan, 'syncPlan');
      final remoteRecords = _recordList(plan['records']);
      final neededUploads =
          (plan['needAssets'] as List?)?.whereType<String>().toSet() ??
          const <String>{};
      final assetById = {for (final asset in assets) asset.id: asset};
      for (final id in neededUploads) {
        final asset = assetById[id];
        if (asset == null) continue;
        transferredBytes += await _sendAsset(
          connection,
          cipher,
          asset,
          onProgress: (sent) {
            onProgress?.call(
              SyncProgress(
                totalRecords: records.length + remoteRecords.length,
                totalBytes: totalBytes,
                completedBytes: transferredBytes + sent,
              ),
            );
          },
        );
      }
      await connection.sendEncrypted(cipher, {'kind': 'uploadsComplete'});

      final remoteManifests = _assetManifestList(plan['assets']);
      final requestedDownloads = <String>[];
      for (final manifest in remoteManifests) {
        if (!await repository.hasAsset(manifest.id, manifest.sha256)) {
          requestedDownloads.add(manifest.id);
        }
      }
      await connection.sendEncrypted(cipher, {
        'kind': 'requestAssets',
        'ids': requestedDownloads,
      });
      transferredBytes += await _receiveAssets(connection, cipher, {
        for (final item in remoteManifests) item.id: item,
      }, requestedDownloads.toSet());

      final reconcile = await repository.reconcileRemote(
        remoteRecords,
        pairedPeer.deviceId,
      );
      await repository.markPeerSynced(pairedPeer.deviceId);
      await connection.sendEncrypted(cipher, {
        'kind': 'applyComplete',
        'appliedRecords': reconcile.appliedCount,
        'conflicts': reconcile.conflicts.length,
      });
      final completed = await connection.nextEncrypted(cipher);
      _expectKind(completed, 'syncComplete');
      onProgress?.call(
        SyncProgress(
          completedRecords: records.length + remoteRecords.length,
          totalRecords: records.length + remoteRecords.length,
          completedBytes: transferredBytes,
          totalBytes: transferredBytes,
        ),
      );
      return SyncClientResult(
        appliedRecords: reconcile.appliedCount,
        conflicts: reconcile.conflicts.length,
        transferredBytes: transferredBytes,
      );
    } finally {
      await connection.close();
    }
  }

  Future<int> _sendAsset(
    _SyncConnection connection,
    SyncSessionCipher cipher,
    SyncAsset asset, {
    required void Function(int sent) onProgress,
  }) async {
    final file = File(asset.path);
    final bytes = await file.readAsBytes();
    var offset = 0;
    while (offset < bytes.length) {
      final end = (offset + _chunkSize).clamp(0, bytes.length);
      final chunk = bytes.sublist(offset, end);
      await connection.sendEncrypted(cipher, {
        'kind': 'assetChunk',
        'id': asset.id,
        'sha256': asset.sha256,
        'size': asset.size,
        'offset': offset,
        'data': base64Encode(chunk),
        'final': end == bytes.length,
      });
      offset = end;
      onProgress(offset);
    }
    return bytes.length;
  }

  Future<int> _receiveAssets(
    _SyncConnection connection,
    SyncSessionCipher cipher,
    Map<String, _AssetManifest> manifests,
    Set<String> requested,
  ) async {
    final builders = <String, BytesBuilder>{};
    var receivedBytes = 0;
    while (true) {
      final message = await connection.nextEncrypted(cipher);
      final kind = message['kind'];
      if (kind == 'assetsComplete') break;
      _expectKind(message, 'assetChunk');
      final id = message['id']! as String;
      final manifest = manifests[id];
      if (!requested.contains(id) || manifest == null) {
        throw const FormatException('Received an unrequested sync asset.');
      }
      final builder = builders.putIfAbsent(id, BytesBuilder.new);
      final expectedOffset = builder.length;
      final offset = (message['offset']! as num).toInt();
      if (offset != expectedOffset) {
        throw const FormatException('Sync asset chunk is out of order.');
      }
      final data = base64Decode(message['data']! as String);
      builder.add(data);
      receivedBytes += data.length;
      if (builder.length > manifest.size || builder.length > 32 * 1024 * 1024) {
        throw const FormatException('Sync asset exceeds its declared size.');
      }
      if (message['final'] == true) {
        if (builder.length != manifest.size) {
          throw const FormatException('Sync asset size mismatch.');
        }
        await repository.storeAsset(id, builder.takeBytes(), manifest.sha256);
        builders.remove(id);
        requested.remove(id);
      }
    }
    if (requested.isNotEmpty || builders.isNotEmpty) {
      throw const FormatException('Sync asset transfer ended prematurely.');
    }
    return receivedBytes;
  }

  List<SyncRecord> _recordList(Object? value) {
    if (value is! List) throw const FormatException('Invalid sync records.');
    if (value.length > 100000) {
      throw const FormatException('Sync record count is too large.');
    }
    return value
        .map(
          (item) => SyncRecord.fromJson(
            (item as Map).map((key, entry) => MapEntry(key.toString(), entry)),
          ),
        )
        .toList(growable: false);
  }

  List<_AssetManifest> _assetManifestList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) {
          final map = item as Map;
          return _AssetManifest(
            id: map['id']! as String,
            size: (map['size']! as num).toInt(),
            sha256: map['sha256']! as String,
          );
        })
        .toList(growable: false);
  }

  Future<_SyncConnection> _open(SyncPeer peer) async {
    final channel = _connectChannel(peer.endpoint);
    await channel.ready.timeout(const Duration(seconds: 8));
    return _SyncConnection(channel);
  }

  static WebSocketChannel _defaultConnect(Uri endpoint) {
    return IOWebSocketChannel.connect(
      endpoint,
      protocols: const [_protocol],
      pingInterval: const Duration(seconds: 15),
      connectTimeout: const Duration(seconds: 8),
    );
  }

  static void _expectKind(Map<String, Object?> message, String expected) {
    if (message['kind'] != expected) {
      final error = message['error'];
      throw FormatException(
        error is String ? error : 'Expected sync message $expected.',
      );
    }
  }
}

class _AssetManifest {
  const _AssetManifest({
    required this.id,
    required this.size,
    required this.sha256,
  });

  final String id;
  final int size;
  final String sha256;
}

class _SyncConnection {
  _SyncConnection(this.channel) : _iterator = StreamIterator(channel.stream);

  final WebSocketChannel channel;
  final StreamIterator<dynamic> _iterator;

  void sendPlain(Map<String, Object?> message) {
    channel.sink.add(jsonEncode(message));
  }

  Future<Map<String, Object?>> nextPlain() async {
    final raw = await _next();
    if (raw is! String || raw.length > 64 * 1024) {
      throw const FormatException('Invalid sync handshake message.');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Invalid sync handshake payload.');
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<void> sendEncrypted(
    SyncSessionCipher cipher,
    Map<String, Object?> message,
  ) async {
    channel.sink.add(await cipher.encrypt(message));
  }

  Future<Map<String, Object?>> nextEncrypted(SyncSessionCipher cipher) async {
    return cipher.decrypt(await _next());
  }

  Future<Object?> _next() async {
    if (!await _iterator.moveNext().timeout(const Duration(seconds: 45))) {
      throw WebSocketChannelException('Sync connection closed.');
    }
    return _iterator.current;
  }

  Future<void> close() async {
    await _iterator.cancel();
    await channel.sink.close(status.normalClosure, 'sync complete');
  }
}
