import 'package:flutter/material.dart';

import '../settings/app_settings.dart';

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class AppTheme {
  static const double cardRadius = 16;

  static ThemeData light(ThemeSeed seed, {ColorScheme? dynamicColorScheme}) =>
      _build(Brightness.light, seed, dynamicColorScheme: dynamicColorScheme);

  static ThemeData dark(ThemeSeed seed, {ColorScheme? dynamicColorScheme}) =>
      _build(Brightness.dark, seed, dynamicColorScheme: dynamicColorScheme);

  static ThemeData _build(
    Brightness brightness,
    ThemeSeed seed, {
    ColorScheme? dynamicColorScheme,
  }) {
    final isDark = brightness == Brightness.dark;
    final baseScheme = switch (seed) {
      ThemeSeed.neutral => _neutralScheme(brightness),
      ThemeSeed.monet =>
        dynamicColorScheme ??
            ColorScheme.fromSeed(seedColor: seed.color, brightness: brightness),
      _ => ColorScheme.fromSeed(seedColor: seed.color, brightness: brightness),
    };
    final scheme = baseScheme.copyWith(
      surface: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFFAFAFA),
    );
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.55);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF111111)
          : const Color(0xFFF4F4F4),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: borderColor),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: seed == ThemeSeed.neutral
            ? (isDark ? const Color(0xFFD8D8D8) : const Color(0xFFE4E4E4))
            : scheme.secondaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: seed == ThemeSeed.neutral
                  ? Colors.black
                  : scheme.onSecondaryContainer,
              size: 24,
            );
          }
          return IconThemeData(color: scheme.onSurfaceVariant, size: 24);
        }),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: scheme.onSurface, fontSize: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dividerTheme: DividerThemeData(color: borderColor),
    );
  }

  static ColorScheme _neutralScheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const black = Color(0xFF000000);
    const white = Color(0xFFFFFFFF);
    const darkControl = Color(0xFFE5E5E5);
    const darkControlContainer = Color(0xFFD8D8D8);
    const darkOnControl = Color(0xFF171717);
    return ColorScheme.fromSeed(
      seedColor: black,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? darkControl : black,
      onPrimary: isDark ? darkOnControl : white,
      primaryContainer: isDark ? darkControlContainer : black,
      onPrimaryContainer: isDark ? darkOnControl : white,
      secondary: isDark ? darkControl : black,
      onSecondary: isDark ? darkOnControl : white,
      secondaryContainer: isDark ? darkControlContainer : black,
      onSecondaryContainer: isDark ? darkOnControl : white,
      tertiary: isDark ? darkControl : black,
      onTertiary: isDark ? darkOnControl : white,
      tertiaryContainer: isDark ? darkControlContainer : black,
      onTertiaryContainer: isDark ? darkOnControl : white,
      surfaceTint: isDark ? darkControl : black,
      onSurface: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF171717),
      onSurfaceVariant: isDark
          ? const Color(0xFFD4D4D4)
          : const Color(0xFF525252),
      outline: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF737373),
      outlineVariant: isDark
          ? const Color(0xFF525252)
          : const Color(0xFFD4D4D4),
      surfaceDim: isDark ? const Color(0xFF111111) : const Color(0xFFD4D4D4),
      surfaceBright: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFFFFFFF),
      surfaceContainerLowest: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFFFFFFF),
      surfaceContainerLow: isDark
          ? const Color(0xFF1C1C1C)
          : const Color(0xFFF5F5F5),
      surfaceContainer: isDark
          ? const Color(0xFF242424)
          : const Color(0xFFEEEEEE),
      surfaceContainerHigh: isDark
          ? const Color(0xFF2C2C2C)
          : const Color(0xFFE7E7E7),
      surfaceContainerHighest: isDark
          ? const Color(0xFF3A3A3A)
          : const Color(0xFFDCDCDC),
      inverseSurface: isDark
          ? const Color(0xFFF5F5F5)
          : const Color(0xFF262626),
      onInverseSurface: isDark
          ? const Color(0xFF171717)
          : const Color(0xFFFAFAFA),
      inversePrimary: isDark ? black : white,
      primaryFixed: black,
      primaryFixedDim: const Color(0xFF262626),
      onPrimaryFixed: white,
      onPrimaryFixedVariant: const Color(0xFFE5E5E5),
      secondaryFixed: black,
      secondaryFixedDim: const Color(0xFF262626),
      onSecondaryFixed: white,
      onSecondaryFixedVariant: const Color(0xFFE5E5E5),
      tertiaryFixed: black,
      tertiaryFixedDim: const Color(0xFF262626),
      onTertiaryFixed: white,
      onTertiaryFixedVariant: const Color(0xFFE5E5E5),
    );
  }
}

extension ThemeSeedColor on ThemeSeed {
  Color get color => switch (this) {
    ThemeSeed.neutral => const Color(0xFF000000),
    ThemeSeed.indigo => const Color(0xFF4F46E5),
    ThemeSeed.teal => const Color(0xFF0F766E),
    ThemeSeed.rose => const Color(0xFFE11D48),
    ThemeSeed.monet => const Color(0xFF6750A4),
  };
}
