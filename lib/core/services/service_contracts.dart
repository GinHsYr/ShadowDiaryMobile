import 'package:local_auth/local_auth.dart';

enum DeviceAuthenticationResult { success, canceled, unavailable, failed }

abstract interface class DeviceAuthenticationService {
  Future<bool> isAvailable();

  Future<DeviceAuthenticationResult> authenticate(String localizedReason);
}

class LocalDeviceAuthenticationService implements DeviceAuthenticationService {
  LocalDeviceAuthenticationService({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<bool> isAvailable() => _authentication.isDeviceSupported();

  @override
  Future<DeviceAuthenticationResult> authenticate(
    String localizedReason,
  ) async {
    try {
      final authenticated = await _authentication.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return authenticated
          ? DeviceAuthenticationResult.success
          : DeviceAuthenticationResult.failed;
    } on LocalAuthException catch (error) {
      return switch (error.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout => DeviceAuthenticationResult.canceled,
        LocalAuthExceptionCode.noCredentialsSet =>
          DeviceAuthenticationResult.unavailable,
        _ => DeviceAuthenticationResult.failed,
      };
    } on Object {
      return DeviceAuthenticationResult.failed;
    }
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
