import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/service_contracts.dart';
import '../settings/app_settings_controller.dart';

enum AppLockResult { success, canceled, unavailable, failed }

class AppLockState {
  const AppLockState({
    required this.enabled,
    required this.isLocked,
    this.isAuthenticating = false,
    this.lastResult,
  });

  const AppLockState.disabled()
    : enabled = false,
      isLocked = false,
      isAuthenticating = false,
      lastResult = null;

  final bool enabled;
  final bool isLocked;
  final bool isAuthenticating;
  final AppLockResult? lastResult;

  AppLockState copyWith({
    bool? enabled,
    bool? isLocked,
    bool? isAuthenticating,
    AppLockResult? lastResult,
    bool clearLastResult = false,
  }) {
    return AppLockState(
      enabled: enabled ?? this.enabled,
      isLocked: isLocked ?? this.isLocked,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      lastResult: clearLastResult ? null : lastResult ?? this.lastResult,
    );
  }
}

final deviceAuthenticationServiceProvider =
    Provider<DeviceAuthenticationService>((ref) {
      return LocalDeviceAuthenticationService();
    });

final appLockControllerProvider =
    NotifierProvider<AppLockController, AppLockState>(AppLockController.new);

class AppLockController extends Notifier<AppLockState> {
  Future<AppLockResult>? _pendingAuthentication;

  @override
  AppLockState build() {
    final enabled = ref.read(appSettingsControllerProvider).appLockEnabled;
    return AppLockState(enabled: enabled, isLocked: enabled);
  }

  Future<AppLockResult> enable(String localizedReason) async {
    if (state.enabled) {
      return AppLockResult.success;
    }

    final result = await _authenticate(localizedReason);
    if (result != AppLockResult.success) {
      return result;
    }

    try {
      await ref
          .read(appSettingsControllerProvider.notifier)
          .setAppLockEnabled(true);
      state = const AppLockState(enabled: true, isLocked: false);
      return AppLockResult.success;
    } on Object {
      state = const AppLockState(
        enabled: false,
        isLocked: false,
        lastResult: AppLockResult.failed,
      );
      return AppLockResult.failed;
    }
  }

  Future<AppLockResult> disable(String localizedReason) async {
    if (!state.enabled) {
      return AppLockResult.success;
    }

    final result = await _authenticate(localizedReason);
    if (result != AppLockResult.success) {
      return result;
    }

    try {
      await ref
          .read(appSettingsControllerProvider.notifier)
          .setAppLockEnabled(false);
      state = const AppLockState.disabled();
      return AppLockResult.success;
    } on Object {
      state = state.copyWith(lastResult: AppLockResult.failed);
      return AppLockResult.failed;
    }
  }

  void lock() {
    if (!state.enabled || state.isLocked || state.isAuthenticating) {
      return;
    }
    state = state.copyWith(isLocked: true, clearLastResult: true);
  }

  Future<AppLockResult> unlock(String localizedReason) async {
    if (!state.enabled || !state.isLocked) {
      return AppLockResult.success;
    }

    final result = await _authenticate(localizedReason);
    if (result == AppLockResult.success) {
      state = state.copyWith(isLocked: false, clearLastResult: true);
    }
    return result;
  }

  Future<AppLockResult> _authenticate(String localizedReason) {
    final pending = _pendingAuthentication;
    if (pending != null) {
      return pending;
    }

    final authentication = _performAuthentication(localizedReason);
    _pendingAuthentication = authentication;
    return authentication.whenComplete(() {
      _pendingAuthentication = null;
    });
  }

  Future<AppLockResult> _performAuthentication(String localizedReason) async {
    state = state.copyWith(isAuthenticating: true, clearLastResult: true);

    AppLockResult result;
    try {
      final service = ref.read(deviceAuthenticationServiceProvider);
      if (!await service.isAvailable()) {
        result = AppLockResult.unavailable;
      } else {
        result = switch (await service.authenticate(localizedReason)) {
          DeviceAuthenticationResult.success => AppLockResult.success,
          DeviceAuthenticationResult.canceled => AppLockResult.canceled,
          DeviceAuthenticationResult.unavailable => AppLockResult.unavailable,
          DeviceAuthenticationResult.failed => AppLockResult.failed,
        };
      }
    } on Object {
      result = AppLockResult.failed;
    }

    state = state.copyWith(
      isAuthenticating: false,
      lastResult: result == AppLockResult.success ? null : result,
      clearLastResult: result == AppLockResult.success,
    );
    return result;
  }
}
