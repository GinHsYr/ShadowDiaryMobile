import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/app_localizations.dart';
import '../core/widgets/app_page.dart';
import 'app_ionicons.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  static const desktopContentRadius = 8.0;

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDesktop = AppPage.isDesktop(context);
    final desktopContent = Row(
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
        Expanded(
          child: ClipRRect(
            key: const Key('desktop-content-clip'),
            borderRadius: BorderRadius.circular(desktopContentRadius),
            clipBehavior: Clip.antiAlias,
            child: ColoredBox(
              key: const Key('desktop-content-surface'),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: navigationShell,
            ),
          ),
        ),
      ],
    );
    final desktopContentWithBackdrop = ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: desktopContent,
      ),
    );
    return Scaffold(
      extendBody: !isDesktop,
      backgroundColor:
          isDesktop && Theme.of(context).platform == TargetPlatform.windows
          ? Colors.transparent
          : null,
      body: isDesktop
          ? (Theme.of(context).platform == TargetPlatform.windows
                ? ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                      child: Column(
                        children: [
                          DesktopTitleBar(l10n: l10n),
                          Expanded(child: desktopContent),
                        ],
                      ),
                    ),
                  )
                : desktopContentWithBackdrop)
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

class DesktopTitleBar extends StatelessWidget {
  const DesktopTitleBar({required this.l10n, super.key});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final chromeColor = colors.surface.withValues(alpha: isDark ? 0.48 : 0.38);
    return SizedBox(
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(color: chromeColor),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () async {
                  if (await windowManager.isMaximized()) {
                    await windowManager.unmaximize();
                  } else {
                    await windowManager.maximize();
                  }
                },
                onPanStart: (_) => windowManager.startDragging(),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Image.asset(
                      'resources/icon.png',
                      key: const Key('desktop-titlebar-icon'),
                      width: 21,
                      height: 21,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      l10n.appName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _WindowButton(
              icon: Icons.remove_rounded,
              label: l10n.windowMinimize,
              onPressed: windowManager.minimize,
            ),
            _WindowMaximizeButton(l10n: l10n),
            _WindowButton(
              icon: Icons.close_rounded,
              label: l10n.windowClose,
              destructive: true,
              onPressed: windowManager.close,
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowMaximizeButton extends StatefulWidget {
  const _WindowMaximizeButton({required this.l10n});

  final AppLocalizations l10n;

  @override
  State<_WindowMaximizeButton> createState() => _WindowMaximizeButtonState();
}

class _WindowMaximizeButtonState extends State<_WindowMaximizeButton> {
  bool _maximized = false;

  Future<void> _toggle() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    if (mounted) setState(() => _maximized = !_maximized);
  }

  @override
  Widget build(BuildContext context) {
    return _WindowButton(
      icon: _maximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
      label: _maximized
          ? widget.l10n.windowRestore
          : widget.l10n.windowMaximize,
      onPressed: _toggle,
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: IconButton(
        icon: Icon(icon, size: 17),
        tooltip: label,
        onPressed: onPressed,
        splashRadius: 18,
        color: destructive ? colors.error : colors.onSurfaceVariant,
        hoverColor: destructive
            ? colors.error.withValues(alpha: 0.14)
            : colors.onSurface.withValues(alpha: 0.10),
      ),
    );
  }
}

class DesktopNavigationRail extends StatefulWidget {
  const DesktopNavigationRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.l10n,
    super.key,
  });

  static const collapsedWidth = 80.0;
  static const expandedWidth = 224.0;

  /// The default width used by the desktop shell when the rail is collapsed.
  static const width = collapsedWidth;

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final AppLocalizations l10n;

  @override
  State<DesktopNavigationRail> createState() => _DesktopNavigationRailState();
}

class _DesktopNavigationRailState extends State<DesktopNavigationRail> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: colors.surface.withValues(alpha: isDark ? 0.48 : 0.38),
      child: SafeArea(
        right: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: _isExpanded
              ? DesktopNavigationRail.expandedWidth
              : DesktopNavigationRail.collapsedWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DesktopSidebarToggle(
                expanded: _isExpanded,
                l10n: widget.l10n,
                onPressed: () {
                  setState(() => _isExpanded = !_isExpanded);
                },
              ),
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: 0.7),
              ),
              Expanded(
                child: _DesktopDestinations(
                  expanded: _isExpanded,
                  selectedIndex: widget.selectedIndex,
                  onDestinationSelected: widget.onDestinationSelected,
                  l10n: widget.l10n,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopSidebarToggle extends StatelessWidget {
  const _DesktopSidebarToggle({
    required this.expanded,
    required this.l10n,
    required this.onPressed,
  });

  final bool expanded;
  final AppLocalizations l10n;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = expanded
        ? l10n.desktopSidebarCollapse
        : l10n.desktopSidebarExpand;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            overlayColor: WidgetStatePropertyAll(
              colors.onSurface.withValues(alpha: 0.12),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? 16 : 0,
                vertical: 10,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: expanded ? 48 : DesktopNavigationRail.collapsedWidth,
                    child: Center(child: Icon(Icons.menu_rounded, size: 26)),
                  ),
                  ClipRect(
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerLeft,
                      widthFactor: expanded ? 1 : 0,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopDestinations extends StatelessWidget {
  const _DesktopDestinations({
    required this.expanded,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.l10n,
  });

  final bool expanded;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isNeutralLight = !isDark && colors.secondaryContainer == Colors.black;
    final selectedBackground = isDark || isNeutralLight
        ? const Color(0xFFCBCBCB)
        : colors.secondaryContainer;
    final selectedForeground = isDark || isNeutralLight
        ? Colors.black
        : colors.onSecondaryContainer;
    final destinations = [
      (AppIonicons.bookOutline, l10n.navigationHome),
      (AppIonicons.folderOpenOutline, l10n.navigationArchives),
      (AppIonicons.imagesOutline, l10n.navigationMedia),
      (AppIonicons.settingsOutline, l10n.navigationSettings),
    ];
    final destinationList = ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      itemCount: destinations.length,
      itemBuilder: (context, index) {
        final destination = destinations[index];
        final selected = selectedIndex == index;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: selected ? selectedBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onDestinationSelected(index),
              overlayColor: WidgetStatePropertyAll(
                (selected ? selectedForeground : colors.onSurface).withValues(
                  alpha: 0.12,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: expanded ? 16 : 0,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: expanded ? 48 : 56,
                      child: Center(
                        child: Icon(
                          destination.$1,
                          size: 26,
                          color: selected
                              ? selectedForeground
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    ClipRect(
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.centerLeft,
                        widthFactor: expanded ? 1 : 0,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(
                            destination.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: selected
                                  ? selectedForeground
                                  : colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        // Keep the rail type in the desktop tree for integrations that query
        // the shell's navigation surface; the custom rows own all visuals.
        IgnorePointer(
          child: Opacity(
            opacity: 0,
            child: NavigationRail(
              destinations: [
                NavigationRailDestination(
                  icon: const SizedBox.shrink(),
                  label: const SizedBox.shrink(),
                ),
              ],
              selectedIndex: 0,
            ),
          ),
        ),
        destinationList,
      ],
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
