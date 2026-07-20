import 'package:flutter/material.dart';

enum AppThemeMode { system, light, dark }

enum ThemeSeed { neutral, indigo, teal, rose, monet }

enum AppLocalePreference { system, zh, en }

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

class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.themeSeed = ThemeSeed.neutral,
    this.localePreference = AppLocalePreference.system,
  });

  final AppThemeMode themeMode;
  final ThemeSeed themeSeed;
  final AppLocalePreference localePreference;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    ThemeSeed? themeSeed,
    AppLocalePreference? localePreference,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      themeSeed: themeSeed ?? this.themeSeed,
      localePreference: localePreference ?? this.localePreference,
    );
  }
}
