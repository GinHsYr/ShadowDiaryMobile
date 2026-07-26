import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class PairedPeerSecret {
  const PairedPeerSecret({
    required this.deviceId,
    required this.name,
    required this.secret,
  });

  final String deviceId;
  final String name;
  final List<int> secret;
}

abstract interface class SyncSecureStore {
  Future<String> getOrCreateDeviceId();

  Future<Map<String, PairedPeerSecret>> loadPeerSecrets();

  Future<void> savePeerSecret(PairedPeerSecret value);

  Future<void> deletePeerSecret(String deviceId);
}

class DeviceSyncSecureStore implements SyncSecureStore {
  DeviceSyncSecureStore({FlutterSecureStorage? storage, Uuid? uuid})
    : _storage = storage ?? const FlutterSecureStorage(),
      _uuid = uuid ?? const Uuid();

  static const _deviceIdKey = 'sync.device_id';
  static const _peerPrefix = 'sync.peer.';

  final FlutterSecureStorage _storage;
  final Uuid _uuid;

  @override
  Future<String> getOrCreateDeviceId() async {
    final existing = (await _storage.read(key: _deviceIdKey))?.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _uuid.v4();
    await _storage.write(key: _deviceIdKey, value: created);
    return created;
  }

  @override
  Future<Map<String, PairedPeerSecret>> loadPeerSecrets() async {
    final values = await _storage.readAll();
    final peers = <String, PairedPeerSecret>{};
    for (final entry in values.entries) {
      if (!entry.key.startsWith(_peerPrefix)) continue;
      try {
        final decoded = jsonDecode(entry.value);
        if (decoded is! Map) continue;
        final deviceId = decoded['deviceId'] as String?;
        final name = decoded['name'] as String?;
        final secret = decoded['secret'] as String?;
        if (deviceId == null || name == null || secret == null) continue;
        peers[deviceId] = PairedPeerSecret(
          deviceId: deviceId,
          name: name,
          secret: base64Decode(secret),
        );
      } on Object {
        // Ignore one malformed peer without making all other pairings unusable.
      }
    }
    return peers;
  }

  @override
  Future<void> savePeerSecret(PairedPeerSecret value) {
    return _storage.write(
      key: '$_peerPrefix${value.deviceId}',
      value: jsonEncode({
        'deviceId': value.deviceId,
        'name': value.name,
        'secret': base64Encode(value.secret),
      }),
    );
  }

  @override
  Future<void> deletePeerSecret(String deviceId) {
    return _storage.delete(key: '$_peerPrefix$deviceId');
  }
}
