import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../l10n/app_localizations.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsControllerProvider);
    final controller = ref.read(appSettingsControllerProvider.notifier);

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(l10n.settingsAppearance),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingsDropdown<AppThemeMode>(
                    key: const Key('theme-mode-selector'),
                    label: l10n.settingsThemeMode,
                    value: settings.themeMode,
                    options: {
                      AppThemeMode.system: l10n.themeSystem,
                      AppThemeMode.light: l10n.themeLight,
                      AppThemeMode.dark: l10n.themeDark,
                    },
                    onChanged: controller.setThemeMode,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _FieldLabel(l10n.settingsThemeColor),
                  _ThemeSeedSelector(
                    value: settings.themeSeed,
                    labels: {
                      for (final seed in ThemeSeed.values)
                        seed: _themeSeedLabel(l10n, seed),
                    },
                    onChanged: controller.setThemeSeed,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SettingsDropdown<AppLocalePreference>(
                    key: const Key('locale-selector'),
                    label: l10n.settingsLanguage,
                    value: settings.localePreference,
                    options: {
                      AppLocalePreference.system: l10n.languageSystem,
                      AppLocalePreference.zh: l10n.languageChinese,
                      AppLocalePreference.en: l10n.languageEnglish,
                    },
                    onChanged: controller.setLocalePreference,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(l10n.settingsServices),
          Card(
            child: Column(
              children: [
                ListTile(
                  enabled: false,
                  leading: const Icon(Icons.fingerprint_rounded),
                  title: Text(l10n.biometricLock),
                  subtitle: Text(l10n.notConfigured),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
                const Divider(height: 1),
                ListTile(
                  enabled: false,
                  leading: const Icon(Icons.sync_rounded),
                  title: Text(l10n.lanSync),
                  subtitle: Text(l10n.notConfigured),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _themeSeedLabel(AppLocalizations l10n, ThemeSeed seed) {
    return switch (seed) {
      ThemeSeed.neutral => l10n.colorNeutral,
      ThemeSeed.indigo => l10n.colorIndigo,
      ThemeSeed.teal => l10n.colorTeal,
      ThemeSeed.rose => l10n.colorRose,
      ThemeSeed.monet => l10n.colorMonet,
    };
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class _SettingsDropdown<T> extends StatelessWidget {
  const _SettingsDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final String label;
  final T value;
  final Map<T, String> options;
  final Future<void> Function(T value) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.labelLarge)),
        const SizedBox(width: AppSpacing.md),
        PopupMenuButton<T>(
          initialValue: value,
          tooltip: label,
          position: PopupMenuPosition.under,
          offset: const Offset(0, AppSpacing.sm),
          elevation: 8,
          color: colorScheme.surfaceContainerHigh,
          surfaceTintColor: Colors.transparent,
          constraints: const BoxConstraints(minWidth: 176, maxWidth: 176),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          onSelected: (nextValue) => onChanged(nextValue),
          itemBuilder: (context) => [
            for (final option in options.entries)
              PopupMenuItem<T>(
                value: option.key,
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option.value,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: value == option.key
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                            fontWeight: value == option.key
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (value == option.key) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
          child: Container(
            width: 148,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.65,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    options[value]!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeSeedSelector extends StatelessWidget {
  const _ThemeSeedSelector({
    required this.value,
    required this.labels,
    required this.onChanged,
  });

  final ThemeSeed value;
  final Map<ThemeSeed, String> labels;
  final Future<void> Function(ThemeSeed value) onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        for (final seed in ThemeSeed.values)
          Semantics(
            label: labels[seed],
            button: true,
            selected: value == seed,
            child: Tooltip(
              message: labels[seed]!,
              child: InkResponse(
                key: Key('theme-seed-${seed.name}'),
                onTap: () => onChanged(seed),
                radius: 24,
                customBorder: const CircleBorder(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: value == seed
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: value == seed ? 3 : 1,
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: seed == ThemeSeed.monet ? null : seed.color,
                      gradient: seed == ThemeSeed.monet
                          ? const SweepGradient(
                              colors: [
                                Color(0xFF6750A4),
                                Color(0xFF006A6A),
                                Color(0xFF7D5260),
                                Color(0xFF6750A4),
                              ],
                            )
                          : null,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
