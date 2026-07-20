import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings.dart';
import 'package:shadow_diary_mobile/core/theme/app_theme.dart';

void main() {
  test('neutral theme uses true black for control colors', () {
    for (final theme in [
      AppTheme.light(ThemeSeed.neutral),
      AppTheme.dark(ThemeSeed.neutral),
    ]) {
      expect(theme.colorScheme.primary, Colors.black);
      expect(theme.colorScheme.primaryContainer, Colors.black);
      expect(theme.colorScheme.secondary, Colors.black);
      expect(theme.colorScheme.secondaryContainer, Colors.black);
      expect(theme.colorScheme.surfaceTint, Colors.black);

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
