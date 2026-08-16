import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_page.dart';
import 'app_ionicons.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDesktop = AppPage.isDesktop(context);
    return Scaffold(
      extendBody: !isDesktop,
      body: isDesktop
          ? Row(
              children: [
                DesktopNavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: (index) {
                    navigationShell.goBranch(
                      index,
                      initialLocation: index == navigationShell.currentIndex,
                    );
                  },
                  l10n: l10n,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            )
          : navigationShell,
      bottomNavigationBar: isDesktop
          ? null
          : FrostedNavigationBar(
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

class DesktopNavigationRail extends StatelessWidget {
  const DesktopNavigationRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.l10n,
    super.key,
  });

  static const width = 224.0;

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SizedBox.square(
                        dimension: 40,
                        child: Icon(
                          Icons.auto_stories_rounded,
                          color: colors.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: 0.7),
              ),
              Expanded(
                child: NavigationRail(
                  backgroundColor: Colors.transparent,
                  extended: true,
                  minExtendedWidth: width,
                  groupAlignment: -1,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(AppIonicons.bookOutline),
                      label: Text(l10n.navigationHome),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(AppIonicons.folderOpenOutline),
                      label: Text(l10n.navigationArchives),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(AppIonicons.imagesOutline),
                      label: Text(l10n.navigationMedia),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(AppIonicons.settingsOutline),
                      label: Text(l10n.navigationSettings),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
