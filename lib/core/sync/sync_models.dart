import 'dart:convert';

enum SyncPhase {
  disabled,
  discovering,
  pairing,
  connecting,
  syncing,
  conflicts,
  completed,
  failed,
}

enum SyncEntityType {
  diary('diary'),
  archive('archive');

  const SyncEntityType(this.wireName);

  final String wireName;

  static SyncEntityType fromWireName(String value) {
    return values.firstWhere(
      (type) => type.wireName == value,
      orElse: () => throw FormatException('Unknown sync entity type: $value'),
    );
  }
}

enum SyncConflictChoice { keepLocal, keepRemote, keepBoth }

class SyncPeer {
  const SyncPeer({
    required this.deviceId,
    required this.name,
    required this.host,
    required this.port,
    required this.pairingAvailable,
    this.alternativeHosts = const [],
    this.protocolVersion = 1,
  });

  final String deviceId;
  final String name;
  final String host;
  final List<String> alternativeHosts;
  final int port;
  final bool pairingAvailable;
  final int protocolVersion;

  List<String> get hosts => List.unmodifiable({host, ...alternativeHosts});

  List<Uri> get endpoints => List.unmodifiable(
    hosts.map(
      (candidate) =>
          Uri(scheme: 'ws', host: candidate, port: port, path: '/sync'),
    ),
  );

  Uri get endpoint => endpoints.first;

  SyncPeer copyWith({
    String? name,
    String? host,
    List<String>? alternativeHosts,
    int? port,
    bool? pairingAvailable,
    int? protocolVersion,
  }) {
    return SyncPeer(
      deviceId: deviceId,
      name: name ?? this.name,
      host: host ?? this.host,
      alternativeHosts: alternativeHosts ?? this.alternativeHosts,
      port: port ?? this.port,
      pairingAvailable: pairingAvailable ?? this.pairingAvailable,
      protocolVersion: protocolVersion ?? this.protocolVersion,
    );
  }
}

class SyncProgress {
  const SyncProgress({
    this.completedRecords = 0,
    this.totalRecords = 0,
    this.completedBytes = 0,
    this.totalBytes = 0,
  });

  final int completedRecords;
  final int totalRecords;
  final int completedBytes;
  final int totalBytes;

  double get fraction {
    if (totalBytes > 0) {
      return (completedBytes / totalBytes).clamp(0, 1);
    }
    if (totalRecords > 0) {
      return (completedRecords / totalRecords).clamp(0, 1);
    }
    return 0;
  }
}

class SyncState {
  const SyncState({
    this.phase = SyncPhase.disabled,
    this.peers = const [],
    this.pairedDeviceIds = const {},
    this.progress = const SyncProgress(),
    this.conflictCount = 0,
    this.lastSyncAt,
    this.activePeerId,
    this.error,
  });

  final SyncPhase phase;
  final List<SyncPeer> peers;
  final Set<String> pairedDeviceIds;
  final SyncProgress progress;
  final int conflictCount;
  final DateTime? lastSyncAt;
  final String? activePeerId;
  final String? error;

  bool get isBusy => switch (phase) {
    SyncPhase.pairing || SyncPhase.connecting || SyncPhase.syncing => true,
    _ => false,
  };

  SyncState copyWith({
    SyncPhase? phase,
    List<SyncPeer>? peers,
    Set<String>? pairedDeviceIds,
    SyncProgress? progress,
    int? conflictCount,
    DateTime? lastSyncAt,
    String? activePeerId,
    String? error,
    bool clearActivePeer = false,
    bool clearError = false,
  }) {
    return SyncState(
      phase: phase ?? this.phase,
      peers: peers ?? this.peers,
      pairedDeviceIds: pairedDeviceIds ?? this.pairedDeviceIds,
      progress: progress ?? this.progress,
      conflictCount: conflictCount ?? this.conflictCount,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      activePeerId: clearActivePeer ? null : activePeerId ?? this.activePeerId,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class SyncRecord {
  const SyncRecord({
    required this.entityType,
    required this.entityId,
    required this.versionVector,
    required this.contentHash,
    required this.modifiedAt,
    this.payload,
    this.deletedAt,
  });

  final SyncEntityType entityType;
  final String entityId;
  final Map<String, int> versionVector;
  final String contentHash;
  final int modifiedAt;
  final Map<String, Object?>? payload;
  final int? deletedAt;

  bool get isDeleted => deletedAt != null;

  Map<String, Object?> toJson() => {
    'entityType': entityType.wireName,
    'entityId': entityId,
    'versionVector': versionVector,
    'contentHash': contentHash,
    'modifiedAt': modifiedAt,
    if (payload != null) 'payload': payload,
    if (deletedAt != null) 'deletedAt': deletedAt,
  };

  factory SyncRecord.fromJson(Map<String, Object?> json) {
    final rawVector = json['versionVector'];
    if (rawVector is! Map) {
      throw const FormatException('Sync record has no version vector.');
    }
    final payload = json['payload'];
    return SyncRecord(
      entityType: SyncEntityType.fromWireName(json['entityType']! as String),
      entityId: json['entityId']! as String,
      versionVector: rawVector.map(
        (key, value) => MapEntry(key.toString(), (value as num).toInt()),
      ),
      contentHash: json['contentHash']! as String,
      modifiedAt: (json['modifiedAt']! as num).toInt(),
      payload: payload is Map
          ? payload.map((key, value) => MapEntry(key.toString(), value))
          : null,
      deletedAt: (json['deletedAt'] as num?)?.toInt(),
    );
  }

  SyncRecord copyWith({
    Map<String, int>? versionVector,
    String? contentHash,
    int? modifiedAt,
    Map<String, Object?>? payload,
    int? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return SyncRecord(
      entityType: entityType,
      entityId: entityId,
      versionVector: versionVector ?? this.versionVector,
      contentHash: contentHash ?? this.contentHash,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      payload: payload ?? this.payload,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    );
  }
}

enum VersionRelation { equal, localDescends, remoteDescends, concurrent }

VersionRelation compareVersionVectors(
  Map<String, int> local,
  Map<String, int> remote,
) {
  var localGreater = false;
  var remoteGreater = false;
  for (final deviceId in {...local.keys, ...remote.keys}) {
    final localVersion = local[deviceId] ?? 0;
    final remoteVersion = remote[deviceId] ?? 0;
    if (localVersion > remoteVersion) localGreater = true;
    if (remoteVersion > localVersion) remoteGreater = true;
  }
  if (!localGreater && !remoteGreater) return VersionRelation.equal;
  if (localGreater && !remoteGreater) return VersionRelation.localDescends;
  if (!localGreater && remoteGreater) return VersionRelation.remoteDescends;
  return VersionRelation.concurrent;
}

Map<String, int> mergeVersionVectors(
  Map<String, int> first,
  Map<String, int> second,
) {
  final merged = <String, int>{};
  for (final deviceId in {...first.keys, ...second.keys}) {
    final firstVersion = first[deviceId] ?? 0;
    final secondVersion = second[deviceId] ?? 0;
    merged[deviceId] = firstVersion > secondVersion
        ? firstVersion
        : secondVersion;
  }
  return merged;
}

Map<String, int> incrementVersionVector(
  Map<String, int> vector,
  String deviceId,
) {
  return {...vector, deviceId: (vector[deviceId] ?? 0) + 1};
}

String encodeVersionVector(Map<String, int> value) {
  final sortedKeys = value.keys.toList()..sort();
  return jsonEncode({for (final key in sortedKeys) key: value[key]});
}

Map<String, int> decodeVersionVector(String value) {
  final decoded = jsonDecode(value);
  if (decoded is! Map) return const {};
  return decoded.map(
    (key, item) => MapEntry(key.toString(), (item as num).toInt()),
  );
}

class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.peerDeviceId,
    required this.localVector,
    required this.remoteVector,
    required this.createdAt,
    this.localPayload,
    this.remotePayload,
  });

  final String id;
  final SyncEntityType entityType;
  final String entityId;
  final String peerDeviceId;
  final Map<String, Object?>? localPayload;
  final Map<String, Object?>? remotePayload;
  final Map<String, int> localVector;
  final Map<String, int> remoteVector;
  final DateTime createdAt;
}
