import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';

import 'sync_models.dart';

abstract interface class SyncDiscoveryService {
  Stream<List<SyncPeer>> get peers;

  Future<void> start();

  Future<void> stop();
}

class BonsoirSyncDiscoveryService implements SyncDiscoveryService {
  BonsoirSyncDiscoveryService({BonsoirDiscovery Function()? createDiscovery})
    : _createDiscovery =
          createDiscovery ??
          (() => BonsoirDiscovery(type: '_shadowdiary._tcp'));

  final BonsoirDiscovery Function() _createDiscovery;
  final StreamController<List<SyncPeer>> _peerController =
      StreamController<List<SyncPeer>>.broadcast();
  final Map<String, SyncPeer> _peersByServiceName = {};

  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _subscription;

  @override
  Stream<List<SyncPeer>> get peers => _peerController.stream;

  @override
  Future<void> start() async {
    if (_discovery != null) return;
    final discovery = _createDiscovery();
    _discovery = discovery;
    try {
      await discovery.initialize();
      _subscription = discovery.eventStream!.listen(
        (event) => _handleEvent(discovery, event),
        onError: _peerController.addError,
      );
      await discovery.start();
    } on Object {
      await _subscription?.cancel();
      _subscription = null;
      _discovery = null;
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    final discovery = _discovery;
    _discovery = null;
    await _subscription?.cancel();
    _subscription = null;
    _peersByServiceName.clear();
    _emitPeers();
    if (discovery != null) {
      try {
        await discovery.stop();
      } on Object {
        // Discovery can already be stopped by the platform lifecycle.
      }
    }
  }

  Future<void> dispose() async {
    await stop();
    await _peerController.close();
  }

  void _handleEvent(BonsoirDiscovery discovery, BonsoirDiscoveryEvent event) {
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent():
        unawaited(event.service.resolve(discovery.serviceResolver));
      case BonsoirDiscoveryServiceResolvedEvent():
        _upsert(event.service);
      case BonsoirDiscoveryServiceUpdatedEvent():
        _upsert(event.service);
      case BonsoirDiscoveryServiceLostEvent():
        _peersByServiceName.remove(event.service.name);
        _emitPeers();
      default:
        break;
    }
  }

  void _upsert(BonsoirService service) {
    final attributes = service.attributes;
    final deviceId = attributes['id']?.trim();
    final protocolVersion = int.tryParse(attributes['pv'] ?? '');
    final hosts = syncHostsFromService(service.hostAddresses, service.hostname);
    if (deviceId == null ||
        deviceId.isEmpty ||
        protocolVersion != 1 ||
        hosts.isEmpty ||
        service.port < 1) {
      return;
    }
    _peersByServiceName[service.name] = SyncPeer(
      deviceId: deviceId,
      name: service.name,
      host: hosts.first,
      alternativeHosts: hosts.skip(1).toList(growable: false),
      port: service.port,
      pairingAvailable: attributes['pair'] == '1',
      protocolVersion: protocolVersion!,
    );
    _emitPeers();
  }

  void _emitPeers() {
    final peers = _peersByServiceName.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _peerController.add(List.unmodifiable(peers));
  }
}

List<String> syncHostsFromService(
  Iterable<String> addresses,
  String? hostname,
) {
  final ipv4 = <String>[];
  final globalIpv6 = <String>[];
  final linkLocalIpv6 = <String>[];
  final other = <String>[];
  final seen = <String>{};

  void addAddress(String rawAddress) {
    var address = rawAddress.trim();
    if (address.startsWith('[') && address.endsWith(']')) {
      address = address.substring(1, address.length - 1);
    }
    if (address.isEmpty || !seen.add(address.toLowerCase())) return;
    final parsed = InternetAddress.tryParse(address);
    if (parsed == null) {
      other.add(address);
      return;
    }
    if (parsed.isLoopback ||
        parsed.address == '0.0.0.0' ||
        parsed.address == '::') {
      return;
    }
    if (parsed.type == InternetAddressType.IPv4) {
      if (parsed.address.startsWith('172.25.')) {
        other.add(address);
        return;
      }
      ipv4.add(address);
      return;
    }
    if (parsed.address.toLowerCase().startsWith('fe80:')) {
      linkLocalIpv6.add(address);
    } else {
      globalIpv6.add(address);
    }
  }

  for (final address in addresses) {
    addAddress(address);
  }
  final fallback = hostname?.trim();
  if (fallback != null && fallback.isNotEmpty) addAddress(fallback);
  return List.unmodifiable([
    ...ipv4,
    ...globalIpv6,
    ...linkLocalIpv6,
    ...other,
  ]);
}
