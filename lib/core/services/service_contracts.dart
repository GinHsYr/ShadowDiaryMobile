import 'package:local_auth/local_auth.dart';

abstract interface class BiometricAuthService {
  Future<bool> isAvailable();

  Future<bool> authenticate(String localizedReason);
}

class LocalAuthBiometricService implements BiometricAuthService {
  LocalAuthBiometricService({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<bool> isAvailable() async {
    return await _authentication.isDeviceSupported() &&
        await _authentication.canCheckBiometrics;
  }

  @override
  Future<bool> authenticate(String localizedReason) {
    return _authentication.authenticate(
      localizedReason: localizedReason,
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }
}

class LanPeer {
  const LanPeer({required this.name, required this.host, required this.port});

  final String name;
  final String host;
  final int port;
}

abstract interface class LanDiscoveryService {
  Stream<List<LanPeer>> get peers;

  Future<void> start();

  Future<void> stop();
}

class DisabledLanDiscoveryService implements LanDiscoveryService {
  @override
  Stream<List<LanPeer>> get peers => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

enum SyncStatus { disabled, disconnected, connecting, connected, failed }

abstract interface class SyncTransport {
  Stream<SyncStatus> get status;

  Future<void> connect(Uri endpoint);

  Future<void> disconnect();
}

class DisabledSyncTransport implements SyncTransport {
  @override
  Stream<SyncStatus> get status => Stream.value(SyncStatus.disabled);

  @override
  Future<void> connect(Uri endpoint) async {}

  @override
  Future<void> disconnect() async {}
}

abstract interface class LegacyContentCodec<TDocument> {
  TDocument decodeHtml(String html);

  String encodeHtml(TDocument document);
}
