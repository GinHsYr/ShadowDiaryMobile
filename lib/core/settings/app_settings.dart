import 'package:flutter/material.dart';

enum AppThemeMode { system, light, dark }

enum ThemeSeed { neutral, indigo, teal, rose, monet }

enum AppLocalePreference { system, zh, en }

enum AppLockDelay { oneMinute, fiveMinutes, fifteenMinutes, thirtyMinutes }

extension AppThemeModeValue on AppThemeMode {
  ThemeMode get materialThemeMode => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}

extension AppLocalePreferenceValue on AppLocalePreference {
  Locale? get locale => switch (this) {
    AppLocalePreference.system => null,
    AppLocalePreference.zh => const Locale('zh'),
    AppLocalePreference.en => const Locale('en'),
  };
}

extension AppLockDelayValue on AppLockDelay {
  Duration get duration => switch (this) {
    AppLockDelay.oneMinute => const Duration(minutes: 1),
    AppLockDelay.fiveMinutes => const Duration(minutes: 5),
    AppLockDelay.fifteenMinutes => const Duration(minutes: 15),
    AppLockDelay.thirtyMinutes => const Duration(minutes: 30),
  };
}

class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.themeSeed = ThemeSeed.neutral,
    this.localePreference = AppLocalePreference.system,
    this.appLockEnabled = false,
    this.appLockDelay = AppLockDelay.oneMinute,
  });

  final AppThemeMode themeMode;
  final ThemeSeed themeSeed;
  final AppLocalePreference localePreference;
  final bool appLockEnabled;
  final AppLockDelay appLockDelay;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    ThemeSeed? themeSeed,
    AppLocalePreference? localePreference,
    bool? appLockEnabled,
    AppLockDelay? appLockDelay,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      themeSeed: themeSeed ?? this.themeSeed,
      localePreference: localePreference ?? this.localePreference,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      appLockDelay: appLockDelay ?? this.appLockDelay,
    );
  }
}
