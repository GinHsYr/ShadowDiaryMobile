import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import 'app_ionicons.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: FrostedNavigationBar(
        child: NavigationBar(
          // Keep the Material painted by NavigationBar transparent. The
          // frosted wrapper below owns the glass tint and backdrop blur.
          backgroundColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(AppIonicons.bookOutline),
              label: l10n.navigationHome,
            ),
            NavigationDestination(
              icon: const Icon(AppIonicons.folderOpenOutline),
              label: l10n.navigationArchives,
            ),
            NavigationDestination(
              icon: const Icon(AppIonicons.imagesOutline),
              label: l10n.navigationMedia,
            ),
            NavigationDestination(
              icon: const Icon(AppIonicons.settingsOutline),
              label: l10n.navigationSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class FrostedNavigationBar extends StatelessWidget {
  const FrostedNavigationBar({required this.child, super.key});

  static const double blurSigma = 36;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(
              alpha: isDark ? 0.62 : 0.54,
            ),
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(
                  alpha: isDark ? 0.45 : 0.7,
                ),
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
