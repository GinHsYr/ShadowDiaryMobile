import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/archives/archive_repository.dart';
import '../../core/backup/backup_import_service.dart';
import '../../core/diary/diary_repository.dart';
import '../../core/media/media_library.dart';
import '../../core/security/app_lock_controller.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../l10n/app_localizations.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isInspectingBackup = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsControllerProvider);
    final controller = ref.read(appSettingsControllerProvider.notifier);
    final lockState = ref.watch(appLockControllerProvider);

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
          _SectionTitle(l10n.settingsSecurity),
          Card(
            child: SwitchListTile(
              key: const Key('app-lock-toggle'),
              secondary: const Icon(Icons.fingerprint_rounded),
              title: Text(l10n.appLock),
              subtitle: Text(
                lockState.enabled
                    ? l10n.appLockEnabledDescription
                    : l10n.appLockDisabledDescription,
              ),
              value: lockState.enabled,
              onChanged: lockState.isAuthenticating
                  ? null
                  : (enabled) => _setAppLock(context, ref, enabled),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(l10n.settingsData),
          Card(
            child: ListTile(
              key: const Key('backup-import-tile'),
              leading: const Icon(Icons.settings_backup_restore_rounded),
              title: Text(l10n.backupImport),
              subtitle: Text(
                _isInspectingBackup
                    ? l10n.backupReading
                    : l10n.backupImportDescription,
              ),
              trailing: _isInspectingBackup
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.chevron_right_rounded),
              onTap: _isInspectingBackup
                  ? null
                  : () => unawaited(_selectBackup()),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(l10n.settingsServices),
          Card(
            child: Column(
              children: [
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

  Future<void> _selectBackup() async {
    final service = ref.read(backupImportServiceProvider);
    setState(() => _isInspectingBackup = true);
    BackupImportPreview? preview;
    try {
      preview = await service.selectBackup();
    } on Object catch (error) {
      if (mounted) _showBackupError(error);
      return;
    } finally {
      if (mounted) setState(() => _isInspectingBackup = false);
    }
    if (!mounted || preview == null) return;

    final mode = await showModalBottomSheet<BackupImportMode>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _BackupImportSheet(preview: preview!),
    );
    if (!mounted) return;
    if (mode == null) {
      await service.discardPreview(preview);
      return;
    }
    await _performImport(service, preview, mode);
  }

  Future<void> _performImport(
    BackupImportService service,
    BackupImportPreview preview,
    BackupImportMode mode,
  ) async {
    final l10n = AppLocalizations.of(context);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            key: const Key('backup-import-progress'),
            content: Row(
              children: [
                const SizedBox.square(
                  dimension: 26,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(l10n.backupImporting)),
              ],
            ),
          ),
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    try {
      final result = await service.importBackup(preview, mode);
      if (!mounted) return;
      ref
        ..invalidate(diaryOverviewProvider)
        ..invalidate(diaryEntryListProvider)
        ..invalidate(archiveListProvider)
        ..invalidate(mediaLibraryProvider);
      final message = mode == BackupImportMode.overwrite
          ? l10n.backupOverwriteSuccess(
              result.importedDiaryCount,
              result.importedArchiveCount,
            )
          : l10n.backupIncrementalSuccess(
              result.importedDiaryCount,
              result.skippedDiaryCount,
            );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } on Object catch (error) {
      if (mounted) _showBackupError(error);
      await service.discardPreview(preview);
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  void _showBackupError(Object error) {
    final l10n = AppLocalizations.of(context);
    final message = error is BackupImportException
        ? switch (error.code) {
            BackupImportErrorCode.unavailable => l10n.backupUnavailable,
            BackupImportErrorCode.invalidBackup => l10n.backupInvalid,
            BackupImportErrorCode.unsupportedBackupFormat =>
              l10n.backupUnsupportedFormat,
            BackupImportErrorCode.missingKeyFile => l10n.backupMissingKey,
            BackupImportErrorCode.unreadableFile => l10n.backupUnreadable,
            BackupImportErrorCode.transferInProgress => l10n.backupTransferBusy,
            BackupImportErrorCode.importFailed => l10n.backupImportFailed,
          }
        : l10n.backupImportFailed;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setAppLock(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(appLockControllerProvider.notifier);
    final result = enabled
        ? await controller.enable(l10n.appLockEnableReason)
        : await controller.disable(l10n.appLockDisableReason);
    if (!context.mounted || result == AppLockResult.success) {
      return;
    }

    final message = switch (result) {
      AppLockResult.unavailable => l10n.appLockUnavailable,
      AppLockResult.canceled => l10n.appLockCanceled,
      AppLockResult.failed => l10n.appLockFailed,
      AppLockResult.success => '',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

class _BackupImportSheet extends StatefulWidget {
  const _BackupImportSheet({required this.preview});

  final BackupImportPreview preview;

  @override
  State<_BackupImportSheet> createState() => _BackupImportSheetState();
}

class _BackupImportSheetState extends State<_BackupImportSheet> {
  BackupImportMode _mode = BackupImportMode.overwrite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final exportedAt = DateFormat.yMd(
      locale,
    ).add_Hm().format(widget.preview.exportedAt.toLocal());

    return ConstrainedBox(
      key: const Key('backup-preview-sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.backupPreviewTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.preview.fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    _BackupInfoRow(
                      label: l10n.backupFileName,
                      value: widget.preview.fileName,
                    ),
                    _BackupInfoRow(
                      label: l10n.backupAppVersion,
                      value:
                          '${widget.preview.appName} ${widget.preview.appVersion}',
                    ),
                    _BackupInfoRow(
                      label: l10n.backupExportedAt,
                      value: exportedAt,
                    ),
                    _BackupInfoRow(
                      label: l10n.backupFormatVersion,
                      value: widget.preview.formatVersion.toString(),
                    ),
                    _BackupInfoRow(
                      label: l10n.backupDiaryCount,
                      value: widget.preview.diaryCount.toString(),
                    ),
                    _BackupInfoRow(
                      label: l10n.backupArchiveCount,
                      value: widget.preview.archiveCount.toString(),
                    ),
                    _BackupInfoRow(
                      label: l10n.backupAttachmentCount,
                      value: widget.preview.attachmentCount.toString(),
                    ),
                    _BackupInfoRow(
                      label: l10n.backupMediaCount,
                      value: widget.preview.mediaFileCount.toString(),
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.backupImportMode, style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            LayoutBuilder(
              builder: (context, constraints) {
                final isVertical = constraints.maxWidth < 340;
                return SegmentedButton<BackupImportMode>(
                  key: const Key('backup-import-mode'),
                  direction: isVertical ? Axis.vertical : Axis.horizontal,
                  expandedInsets: isVertical ? null : EdgeInsets.zero,
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: BackupImportMode.overwrite,
                      icon: const Icon(Icons.restore_rounded),
                      label: Text(l10n.backupOverwrite),
                    ),
                    ButtonSegment(
                      value: BackupImportMode.incremental,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: Text(l10n.backupIncremental),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) {
                    setState(() => _mode = selection.single);
                  },
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _mode == BackupImportMode.overwrite
                  ? l10n.backupOverwriteDescription
                  : l10n.backupIncrementalDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (_mode == BackupImportMode.incremental) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                key: const Key('backup-conflict-count'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_busy_outlined,
                      color: colors.onTertiaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${l10n.backupConflictCount}: '
                        '${l10n.backupConflictDiaryCount(widget.preview.conflictDiaryCount)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                TextButton(
                  key: const Key('backup-import-cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                FilledButton.icon(
                  key: const Key('backup-import-confirm'),
                  onPressed: () => Navigator.of(context).pop(_mode),
                  icon: const Icon(Icons.file_download_outlined),
                  label: Text(l10n.backupStartImport),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupInfoRow extends StatelessWidget {
  const _BackupInfoRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
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
