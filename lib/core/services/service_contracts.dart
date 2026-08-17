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
