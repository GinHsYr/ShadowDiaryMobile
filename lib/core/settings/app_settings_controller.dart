import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';
import 'app_settings_repository.dart';

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  throw StateError('AppSettingsRepository must be overridden at bootstrap.');
});

final initialAppSettingsProvider = Provider<AppSettings>((ref) {
  throw StateError('Initial AppSettings must be overridden at bootstrap.');
});

final appSettingsControllerProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

class AppSettingsController extends Notifier<AppSettings> {
  late final AppSettingsRepository _repository;

  @override
  AppSettings build() {
    _repository = ref.read(appSettingsRepositoryProvider);
    return ref.read(initialAppSettingsProvider);
  }

  Future<void> setThemeMode(AppThemeMode value) {
    return _persist(state.copyWith(themeMode: value));
  }

  Future<void> setThemeSeed(ThemeSeed value) {
    return _persist(state.copyWith(themeSeed: value));
  }

  Future<void> setLocalePreference(AppLocalePreference value) {
    return _persist(state.copyWith(localePreference: value));
  }

  Future<void> setAppLockEnabled(bool value) {
    return _persist(state.copyWith(appLockEnabled: value));
  }

  Future<void> _persist(AppSettings next) async {
    await _repository.save(next);
    state = next;
  }
}
