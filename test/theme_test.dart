import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings.dart';
import 'package:shadow_diary_mobile/core/theme/app_theme.dart';

void main() {
  test('neutral theme gives controls readable contrast in both modes', () {
    final lightTheme = AppTheme.light(ThemeSeed.neutral);
    final lightColors = lightTheme.colorScheme;
    expect(lightColors.primary, Colors.black);
    expect(lightColors.primaryContainer, Colors.black);
    expect(lightColors.secondary, Colors.black);
    expect(lightColors.secondaryContainer, Colors.black);
    expect(lightColors.surfaceTint, Colors.black);

    final darkTheme = AppTheme.dark(ThemeSeed.neutral);
    final darkColors = darkTheme.colorScheme;
    expect(darkColors.primary, const Color(0xFFE5E5E5));
    expect(darkColors.onPrimary, const Color(0xFF171717));
    expect(darkColors.primaryContainer, const Color(0xFFD8D8D8));
    expect(darkColors.onPrimaryContainer, const Color(0xFF171717));
    expect(darkColors.secondaryContainer, const Color(0xFFD8D8D8));
    expect(darkColors.onSecondaryContainer, const Color(0xFF171717));
    expect(darkColors.surfaceTint, const Color(0xFFE5E5E5));
    expect(darkColors.primary, isNot(Colors.black));

    for (final (foreground, background) in [
      (darkColors.onPrimary, darkColors.primary),
      (darkColors.onPrimaryContainer, darkColors.primaryContainer),
      (darkColors.onSecondaryContainer, darkColors.secondaryContainer),
    ]) {
      expect(_contrastRatio(foreground, background), greaterThanOrEqualTo(4.5));
    }
    expect(
      _contrastRatio(darkColors.primary, darkTheme.cardColor),
      greaterThanOrEqualTo(3),
    );

    for (final theme in [lightTheme, darkTheme]) {
      final navigationTheme = theme.navigationBarTheme;
      expect(
        navigationTheme.iconTheme?.resolve({WidgetState.selected})?.color,
        Colors.black,
      );
      expect(navigationTheme.indicatorShape, isA<RoundedRectangleBorder>());
    }

    expect(
      AppTheme.light(ThemeSeed.neutral).navigationBarTheme.indicatorColor,
      const Color(0xFFE4E4E4),
    );
    expect(
      AppTheme.dark(ThemeSeed.neutral).navigationBarTheme.indicatorColor,
      const Color(0xFFD8D8D8),
    );

    for (final theme in [
      AppTheme.light(ThemeSeed.neutral),
      AppTheme.dark(ThemeSeed.neutral),
    ]) {
      final colors = theme.colorScheme;
      expect(
        [
          colors.surface,
          colors.surfaceDim,
          colors.surfaceBright,
          colors.surfaceContainerLowest,
          colors.surfaceContainerLow,
          colors.surfaceContainer,
          colors.surfaceContainerHigh,
          colors.surfaceContainerHighest,
          colors.onSurface,
          colors.onSurfaceVariant,
          colors.outline,
          colors.outlineVariant,
          colors.inverseSurface,
          colors.onInverseSurface,
        ].every(_isGrayscale),
        isTrue,
      );
    }
  });

  test('Monet theme uses the supplied platform color scheme', () {
    final dynamicScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF6F00),
    );

    final theme = AppTheme.light(
      ThemeSeed.monet,
      dynamicColorScheme: dynamicScheme,
    );

    expect(theme.colorScheme.primary, dynamicScheme.primary);
    expect(theme.colorScheme.secondary, dynamicScheme.secondary);
    expect(theme.colorScheme.tertiary, dynamicScheme.tertiary);
  });
}

bool _isGrayscale(Color color) {
  final value = color.toARGB32();
  final red = (value >> 16) & 0xFF;
  final green = (value >> 8) & 0xFF;
  final blue = value & 0xFF;
  return red == green && green == blue;
}

double _contrastRatio(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first
      : second;
  final darker = identical(lighter, first) ? second : first;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
