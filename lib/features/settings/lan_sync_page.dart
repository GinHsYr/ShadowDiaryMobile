import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/sync/sync_controller.dart';
import '../../core/sync/sync_models.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

class LanSyncPage extends ConsumerStatefulWidget {
  const LanSyncPage({super.key});

  @override
  ConsumerState<LanSyncPage> createState() => _LanSyncPageState();
}

class _LanSyncPageState extends ConsumerState<LanSyncPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(syncControllerProvider);
    final conflicts = ref.watch(syncConflictsProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lanSync)),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              sliver: SliverList.list(
                children: [
                  _SyncHeroCard(
                    state: state,
                    animation: _radarController,
                    onSync: state.isBusy
                        ? null
                        : () => ref
                              .read(syncControllerProvider.notifier)
                              .syncNow(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.enhanced_encryption_outlined,
                          color: colors.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            l10n.syncSecureCaption,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _SyncErrorCard(message: _errorLabel(l10n, state.error!)),
                  ],
                  if (state.conflictCount > 0) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _SectionHeader(
                      title: l10n.syncConflictTitle,
                      subtitle: l10n.syncConflictCount(state.conflictCount),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    conflicts.when(
                      data: (items) => Column(
                        children: [
                          for (var index = 0; index < items.length; index++)
                            _Entrance(
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: _ConflictTile(
                                  conflict: items[index],
                                  onTap: () => _showConflict(items[index]),
                                ),
                              ),
                            ),
                        ],
                      ),
                      error: (_, _) => const SizedBox.shrink(),
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _SectionHeader(
                    title: l10n.syncDevices,
                    subtitle: l10n.lanSyncDescription,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (state.peers.isEmpty)
                    _EmptyDevicesCard()
                  else
                    for (var index = 0; index < state.peers.length; index++)
                      _Entrance(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _PeerCard(
                            peer: state.peers[index],
                            paired: state.pairedDeviceIds.contains(
                              state.peers[index].deviceId,
                            ),
                            busy: state.isBusy,
                            onPair: () => _pair(state.peers[index]),
                            onSync: () => ref
                                .read(syncControllerProvider.notifier)
                                .syncNow(state.peers[index]),
                            onUnpair: () => _unpair(state.peers[index]),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pair(SyncPeer peer) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.syncPairCodeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.syncPairCodeHint),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('sync-pair-code-field'),
              controller: controller,
              autofocus: true,
              maxLength: 6,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.syncPairCodeLabel,
                prefixIcon: const Icon(Icons.pin_outlined),
              ),
              onSubmitted: (value) {
                if (value.length == 6) Navigator.of(context).pop(value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('sync-pair-confirm'),
            onPressed: () {
              final value = controller.text;
              if (value.length == 6) Navigator.of(context).pop(value);
            },
            child: Text(l10n.syncPairConfirm),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || !mounted) return;
    try {
      await ref.read(syncControllerProvider.notifier).pair(peer, code);
    } on Object {
      // The controller publishes a localized error code through state.
    }
  }

  Future<void> _unpair(SyncPeer peer) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.syncUnpairTitle),
        content: Text(l10n.syncUnpairHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.syncUnpair),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(syncControllerProvider.notifier).unpair(peer.deviceId);
    }
  }

  Future<void> _showConflict(SyncConflict conflict) async {
    final choice = await showModalBottomSheet<SyncConflictChoice>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _ConflictSheet(conflict: conflict),
      ),
    );
    if (choice != null && mounted) {
      await ref
          .read(syncControllerProvider.notifier)
          .resolveConflict(conflict, choice);
    }
  }

  String _errorLabel(AppLocalizations l10n, String code) => switch (code) {
    'authentication_failed' => l10n.syncErrorAuthentication,
    'invalid_pairing_code' => l10n.syncErrorPairCode,
    'connection_timeout' => l10n.syncErrorTimeout,
    'asset_hash_mismatch' => l10n.syncErrorAsset,
    _ => l10n.syncErrorConnection,
  };
}

class _SyncHeroCard extends StatelessWidget {
  const _SyncHeroCard({
    required this.state,
    required this.animation,
    required this.onSync,
  });

  final SyncState state;
  final Animation<double> animation;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final label = switch (state.phase) {
      SyncPhase.disabled => l10n.syncPaused,
      SyncPhase.discovering => l10n.syncDiscovering,
      SyncPhase.pairing => l10n.syncPairing,
      SyncPhase.connecting => l10n.syncConnecting,
      SyncPhase.syncing => l10n.syncTransferring,
      SyncPhase.conflicts => l10n.syncNeedsAttention,
      SyncPhase.completed => l10n.syncCompleted,
      SyncPhase.failed => l10n.syncFailed,
    };
    final showProgress = state.phase == SyncPhase.syncing;

    return Container(
      key: const Key('sync-hero-card'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withValues(alpha: 0.84),
            colors.tertiaryContainer.withValues(alpha: 0.64),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 340;
          final radar = SizedBox.square(
            dimension: narrow ? 92 : 112,
            child: _SyncRadar(
              animation: animation,
              active: state.phase == SyncPhase.discovering || state.isBusy,
            ),
          );
          final details = Column(
            crossAxisAlignment: narrow
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: Text(
                  label,
                  key: ValueKey(state.phase),
                  textAlign: narrow ? TextAlign.center : TextAlign.start,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                state.lastSyncAt == null
                    ? l10n.lanSyncDescription
                    : l10n.syncLastAt(
                        DateFormat.MMMd(
                          Localizations.localeOf(context).toLanguageTag(),
                        ).add_Hm().format(state.lastSyncAt!),
                      ),
                textAlign: narrow ? TextAlign.center : TextAlign.start,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimaryContainer.withValues(alpha: 0.78),
                ),
              ),
              if (showProgress) ...[
                const SizedBox(height: AppSpacing.md),
                LinearProgressIndicator(
                  value: state.progress.fraction == 0
                      ? null
                      : state.progress.fraction,
                  borderRadius: BorderRadius.circular(99),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                key: const Key('sync-now-button'),
                onPressed: onSync,
                icon: state.isBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
                label: Text(l10n.syncNow),
              ),
            ],
          );
          if (narrow) {
            return Column(
              children: [
                radar,
                const SizedBox(height: AppSpacing.md),
                details,
              ],
            );
          }
          return Row(
            children: [
              radar,
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class _SyncRadar extends StatelessWidget {
  const _SyncRadar({required this.animation, required this.active});

  final Animation<double> animation;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => CustomPaint(
        painter: _RadarPainter(
          progress: active && !reduceMotion ? animation.value : 0.46,
          color: colors.primary,
          active: active,
        ),
        child: Center(
          child: AnimatedScale(
            scale: active && !reduceMotion ? 1.04 : 1,
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutBack,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.28),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: colors.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.progress,
    required this.color,
    required this.active,
  });

  final double progress;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var index = 1; index <= 3; index++) {
      ringPaint.color = color.withValues(alpha: 0.12 + index * 0.04);
      canvas.drawCircle(center, maxRadius * index / 3, ringPaint);
    }
    if (!active) return;
    final waveRadius = maxRadius * (0.24 + progress * 0.76);
    ringPaint
      ..strokeWidth = 2
      ..color = color.withValues(alpha: (1 - progress) * 0.55);
    canvas.drawCircle(center, waveRadius, ringPaint);
    final angle = progress * 6.283185307179586;
    final dot = Offset(
      center.dx + maxRadius * 0.72 * math.cos(angle),
      center.dy + maxRadius * 0.72 * math.sin(angle),
    );
    canvas.drawCircle(dot, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.active != active;
  }
}

class _PeerCard extends StatelessWidget {
  const _PeerCard({
    required this.peer,
    required this.paired,
    required this.busy,
    required this.onPair,
    required this.onSync,
    required this.onUnpair,
  });

  final SyncPeer peer;
  final bool paired;
  final bool busy;
  final VoidCallback onPair;
  final VoidCallback onSync;
  final VoidCallback onUnpair;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: paired
                    ? colors.primaryContainer
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                paired ? Icons.devices_rounded : Icons.desktop_windows_outlined,
                color: paired
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    paired
                        ? l10n.syncPaired
                        : peer.pairingAvailable
                        ? l10n.syncAvailable
                        : l10n.syncUnavailable,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (paired) ...[
              IconButton(
                tooltip: l10n.syncUnpair,
                onPressed: busy ? null : onUnpair,
                icon: const Icon(Icons.link_off_rounded),
              ),
              IconButton.filledTonal(
                tooltip: l10n.syncNow,
                onPressed: busy ? null : onSync,
                icon: const Icon(Icons.sync_rounded),
              ),
            ] else
              FilledButton.tonal(
                onPressed: busy || !peer.pairingAvailable ? null : onPair,
                child: Text(l10n.syncPair),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConflictTile extends StatelessWidget {
  const _ConflictTile({required this.conflict, required this.onTap});

  final SyncConflict conflict;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title =
        _payloadTitle(conflict.localPayload) ??
        _payloadTitle(conflict.remotePayload) ??
        conflict.entityId;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.call_split_rounded),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          conflict.entityType == SyncEntityType.diary
              ? l10n.syncConflictDiary
              : l10n.syncConflictArchive,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _ConflictSheet extends StatelessWidget {
  const _ConflictSheet({required this.conflict});

  final SyncConflict conflict;

  Future<void> _confirmChoice(
    BuildContext context,
    SyncConflictChoice choice,
  ) async {
    final l10n = AppLocalizations.of(context);
    final choiceLabel = switch (choice) {
      SyncConflictChoice.keepLocal => l10n.syncKeepLocal,
      SyncConflictChoice.keepRemote => l10n.syncKeepRemote,
      SyncConflictChoice.keepBoth => l10n.syncKeepBoth,
    };
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('sync-conflict-confirm-dialog'),
        title: Text(l10n.syncConflictConfirmTitle),
        content: Text(l10n.syncConflictConfirmMessage(choiceLabel)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('sync-conflict-confirm-save'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.syncConflictConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) navigator.pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title =
        _payloadTitle(conflict.localPayload) ??
        _payloadTitle(conflict.remotePayload) ??
        conflict.entityId;
    final typeLabel = conflict.entityType == SyncEntityType.diary
        ? l10n.syncConflictDiary
        : l10n.syncConflictArchive;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.syncResolveConflict,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$typeLabel · $title',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: _ConflictDiff(conflict: conflict, title: title),
          ),
        ),
        _ConflictActions(onChoice: (choice) => _confirmChoice(context, choice)),
      ],
    );
  }
}

class _ConflictActions extends StatelessWidget {
  const _ConflictActions({required this.onChoice});

  final ValueChanged<SyncConflictChoice> onChoice;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final buttons = <Widget>[
                FilledButton(
                  key: const Key('sync-conflict-keep-local'),
                  onPressed: () => onChoice(SyncConflictChoice.keepLocal),
                  child: Text(AppLocalizations.of(context).syncKeepLocal),
                ),
                FilledButton.tonal(
                  key: const Key('sync-conflict-keep-remote'),
                  onPressed: () => onChoice(SyncConflictChoice.keepRemote),
                  child: Text(AppLocalizations.of(context).syncKeepRemote),
                ),
                OutlinedButton(
                  key: const Key('sync-conflict-keep-both'),
                  onPressed: () => onChoice(SyncConflictChoice.keepBoth),
                  child: Text(AppLocalizations.of(context).syncKeepBoth),
                ),
              ];
              if (constraints.maxWidth >= 560) {
                return Row(
                  children: [
                    for (var index = 0; index < buttons.length; index++) ...[
                      if (index > 0) const SizedBox(width: AppSpacing.sm),
                      Expanded(child: buttons[index]),
                    ],
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < buttons.length; index++) ...[
                    if (index > 0) const SizedBox(height: AppSpacing.sm),
                    buttons[index],
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ConflictDiff extends StatelessWidget {
  const _ConflictDiff({required this.conflict, required this.title});

  final SyncConflict conflict;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localPlainContent = conflict.localPayload?['plainContent'];
    final remotePlainContent = conflict.remotePayload?['plainContent'];
    final localRichContent = conflict.localPayload?['content'];
    final remoteRichContent = conflict.remotePayload?['content'];
    final includeRichTextSource =
        conflict.entityType == SyncEntityType.diary &&
        localPlainContent == remotePlainContent &&
        localRichContent != remoteRichContent;
    final localSource = _payloadDiffLines(
      conflict.entityType,
      conflict.localPayload,
      l10n,
      includeRichTextSource: includeRichTextSource,
    );
    final remoteSource = _payloadDiffLines(
      conflict.entityType,
      conflict.remotePayload,
      l10n,
      includeRichTextSource: includeRichTextSource,
    );
    _ensureVisibleDifference(
      context,
      conflict,
      localSource,
      remoteSource,
      l10n,
    );
    final localLines = _limitDiffLines(localSource, l10n);
    final remoteLines = _limitDiffLines(remoteSource, l10n);
    final diff = _buildLineDiff(localLines, remoteLines);
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('sync-conflict-diff'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 10,
            ),
            color: colors.surfaceContainerHigh,
            child: Row(
              children: [
                Icon(
                  Icons.compare_arrows_rounded,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _DiffFileHeader(
            key: const Key('sync-diff-local-header'),
            marker: '---',
            label: l10n.syncLocalVersion,
            color: _diffRemovedForeground(context),
          ),
          _DiffFileHeader(
            key: const Key('sync-diff-remote-header'),
            marker: '+++',
            label: l10n.syncRemoteVersion,
            color: _diffAddedForeground(context),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 6,
            ),
            color: colors.primaryContainer.withValues(alpha: 0.55),
            child: Text(
              '@@ -1,${localLines.length} +1,${remoteLines.length} @@',
              style: _diffTextStyle(
                context,
              ).copyWith(color: colors.onPrimaryContainer),
            ),
          ),
          for (final line in diff) _DiffLineRow(line: line),
        ],
      ),
    );
  }
}

class _DiffFileHeader extends StatelessWidget {
  const _DiffFileHeader({
    super.key,
    required this.marker,
    required this.label,
    required this.color,
  });

  final String marker;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 5,
      ),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Text(
        '$marker $label',
        style: _diffTextStyle(
          context,
        ).copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DiffLineRow extends StatelessWidget {
  const _DiffLineRow({required this.line});

  final _DiffLine line;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground, key) = switch (line.kind) {
      _DiffLineKind.removed => (
        _diffRemovedBackground(context),
        _diffRemovedForeground(context),
        const Key('sync-diff-removed'),
      ),
      _DiffLineKind.added => (
        _diffAddedBackground(context),
        _diffAddedForeground(context),
        const Key('sync-diff-added'),
      ),
      _DiffLineKind.context => (
        Colors.transparent,
        colors.onSurfaceVariant,
        const Key('sync-diff-context'),
      ),
    };
    final prefix = switch (line.kind) {
      _DiffLineKind.removed => '-',
      _DiffLineKind.added => '+',
      _DiffLineKind.context => ' ',
    };
    final gutterStyle = _diffTextStyle(
      context,
    ).copyWith(color: foreground.withValues(alpha: 0.72), fontSize: 11);
    return Container(
      key: key,
      constraints: const BoxConstraints(minHeight: 30),
      color: background,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              line.localLine?.toString() ?? '',
              textAlign: TextAlign.end,
              style: gutterStyle,
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              line.remoteLine?.toString() ?? '',
              textAlign: TextAlign.end,
              style: gutterStyle,
            ),
          ),
          SizedBox(
            width: 24,
            child: Text(
              prefix,
              textAlign: TextAlign.center,
              style: _diffTextStyle(
                context,
              ).copyWith(color: foreground, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: SelectableText(
                line.text,
                style: _diffTextStyle(context).copyWith(color: foreground),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _DiffLineKind { context, removed, added }

class _DiffLine {
  const _DiffLine({
    required this.kind,
    required this.text,
    this.localLine,
    this.remoteLine,
  });

  final _DiffLineKind kind;
  final String text;
  final int? localLine;
  final int? remoteLine;
}

class _Entrance extends StatelessWidget {
  const _Entrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + index.clamp(0, 6) * 45),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _EmptyDevicesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.wifi_find_rounded,
            size: 34,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.syncNoDevices,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.syncNoDevicesHint,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SyncErrorCard extends StatelessWidget {
  const _SyncErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.sync_problem_rounded, color: colors.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

String? _payloadTitle(Map<String, Object?>? payload) {
  if (payload == null) return null;
  return (payload['title'] as String?) ?? (payload['name'] as String?);
}

List<String> _payloadDiffLines(
  SyncEntityType entityType,
  Map<String, Object?>? payload,
  AppLocalizations l10n, {
  required bool includeRichTextSource,
}) {
  if (payload == null) return [l10n.syncDiffDeletedVersion];

  final lines = <String>[];
  if (entityType == SyncEntityType.diary) {
    _appendDiffField(lines, l10n.syncDiffTitle, payload['title']);
    _appendDiffField(lines, l10n.searchDateFilter, payload['calendarDate']);
    _appendDiffField(
      lines,
      l10n.editorMood,
      _syncMoodLabel(l10n, payload['mood'] as String?),
    );
    _appendDiffField(lines, l10n.syncDiffWeather, payload['weather']);
    _appendDiffField(lines, l10n.syncDiffTags, payload['tags']);
    _appendDiffField(
      lines,
      l10n.syncDiffContent,
      payload['plainContent'],
      multiline: true,
    );
    _appendDiffField(
      lines,
      l10n.syncDiffImages,
      _diaryImageReferences(payload['content'] as String?),
    );
    if (includeRichTextSource) {
      _appendDiffField(
        lines,
        l10n.syncDiffRichText,
        _formatRichTextSource(payload['content'] as String?),
        multiline: true,
      );
    }
    return lines;
  }

  _appendDiffField(lines, l10n.archiveName, payload['name']);
  _appendDiffField(lines, l10n.archiveAlias, payload['aliases']);
  _appendDiffField(
    lines,
    l10n.archiveType,
    _syncArchiveTypeLabel(l10n, payload['type'] as String?),
  );
  _appendDiffField(
    lines,
    l10n.archiveDescription,
    payload['description'],
    multiline: true,
  );
  _appendDiffField(
    lines,
    l10n.archiveMainImage,
    _compactMediaReference(payload['mainImage'] as String?),
  );
  final images = (payload['images'] as List?)
      ?.whereType<String>()
      .map(_compactMediaReference)
      .toList(growable: false);
  _appendDiffField(lines, l10n.archiveGallery, images);
  return lines;
}

void _ensureVisibleDifference(
  BuildContext context,
  SyncConflict conflict,
  List<String> localLines,
  List<String> remoteLines,
  AppLocalizations l10n,
) {
  if (!_sameDiffLines(localLines, remoteLines)) return;
  final local = conflict.localPayload;
  final remote = conflict.remotePayload;
  if (local == null || remote == null) return;

  final keys = {...local.keys, ...remote.keys}.toList()..sort();
  final differentKeys = keys
      .where((key) => jsonEncode(local[key]) != jsonEncode(remote[key]))
      .toList(growable: false);
  for (final (key, label) in [
    ('updatedAt', l10n.syncDiffUpdatedAt),
    ('createdAt', l10n.syncDiffCreatedAt),
  ]) {
    if (!differentKeys.contains(key)) continue;
    _appendDiffField(
      localLines,
      label,
      _formatDiffTimestamp(context, local[key]),
    );
    _appendDiffField(
      remoteLines,
      label,
      _formatDiffTimestamp(context, remote[key]),
    );
  }
  if (!_sameDiffLines(localLines, remoteLines)) return;

  final reason = differentKeys.isEmpty
      ? 'versionVector'
      : differentKeys.join(', ');
  localLines.add('${l10n.syncDiffOther}: ${l10n.syncLocalVersion} · $reason');
  remoteLines.add('${l10n.syncDiffOther}: ${l10n.syncRemoteVersion} · $reason');
}

bool _sameDiffLines(List<String> local, List<String> remote) {
  if (local.length != remote.length) return false;
  for (var index = 0; index < local.length; index++) {
    if (local[index] != remote[index]) return false;
  }
  return true;
}

String _formatDiffTimestamp(BuildContext context, Object? value) {
  if (value is! num) return _diffDisplayValue(value);
  return DateFormat.yMd(
    Localizations.localeOf(context).toLanguageTag(),
  ).add_Hms().format(DateTime.fromMillisecondsSinceEpoch(value.toInt()));
}

void _appendDiffField(
  List<String> lines,
  String label,
  Object? rawValue, {
  bool multiline = false,
}) {
  final value = _diffDisplayValue(rawValue);
  final valueLines = value
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  if (!multiline && valueLines.length == 1) {
    lines.add('$label: ${valueLines.single}');
    return;
  }
  lines.add('$label:');
  lines.addAll(valueLines.map((line) => '  $line'));
}

String _diffDisplayValue(Object? value) {
  if (value == null) return '—';
  if (value is Iterable) {
    final items = value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return items.isEmpty ? '—' : items.join(', ');
  }
  final text = value.toString().trim();
  return text.isEmpty ? '—' : text;
}

String _syncMoodLabel(AppLocalizations l10n, String? mood) => switch (mood) {
  'happy' => l10n.editorMoodHappy,
  'excited' => l10n.editorMoodExcited,
  'calm' => l10n.editorMoodCalm,
  'tired' => l10n.editorMoodTired,
  'sad' => l10n.editorMoodSad,
  null || '' => '—',
  _ => mood,
};

String _syncArchiveTypeLabel(AppLocalizations l10n, String? type) =>
    switch (type) {
      'person' => l10n.archiveTypePerson,
      'object' => l10n.archiveTypeObject,
      'other' => l10n.archiveTypeOther,
      null || '' => '—',
      _ => type,
    };

List<String> _diaryImageReferences(String? content) {
  if (content == null || content.isEmpty) return const [];
  return RegExp(r'diary-image://[a-zA-Z0-9._-]+')
      .allMatches(content)
      .map((match) => match.group(0))
      .whereType<String>()
      .map(_compactMediaReference)
      .toSet()
      .toList(growable: false);
}

String _compactMediaReference(String? value) {
  if (value == null || value.trim().isEmpty) return '—';
  final normalized = value.trim();
  final separator = normalized.lastIndexOf('/');
  final name = separator < 0 ? normalized : normalized.substring(separator + 1);
  if (name.length <= 30) return name;
  return '${name.substring(0, 14)}…${name.substring(name.length - 11)}';
}

String _formatRichTextSource(String? value) {
  if (value == null || value.trim().isEmpty) return '—';
  return value.trim().replaceAll(RegExp(r'>\s*<'), '>\n<');
}

List<String> _limitDiffLines(List<String> lines, AppLocalizations l10n) {
  const maximumLines = 220;
  const leadingLines = 140;
  const trailingLines = 60;
  if (lines.length <= maximumLines) return lines;
  final omitted = lines.length - leadingLines - trailingLines;
  return [
    ...lines.take(leadingLines),
    l10n.syncDiffOmittedLines(omitted),
    ...lines.skip(lines.length - trailingLines),
  ];
}

List<_DiffLine> _buildLineDiff(
  List<String> localLines,
  List<String> remoteLines,
) {
  final lengths = List.generate(
    localLines.length + 1,
    (_) => List<int>.filled(remoteLines.length + 1, 0),
  );
  for (var local = localLines.length - 1; local >= 0; local--) {
    for (var remote = remoteLines.length - 1; remote >= 0; remote--) {
      lengths[local][remote] = localLines[local] == remoteLines[remote]
          ? lengths[local + 1][remote + 1] + 1
          : math.max(lengths[local + 1][remote], lengths[local][remote + 1]);
    }
  }

  final diff = <_DiffLine>[];
  var local = 0;
  var remote = 0;
  var localLine = 1;
  var remoteLine = 1;
  while (local < localLines.length && remote < remoteLines.length) {
    if (localLines[local] == remoteLines[remote]) {
      diff.add(
        _DiffLine(
          kind: _DiffLineKind.context,
          text: localLines[local],
          localLine: localLine++,
          remoteLine: remoteLine++,
        ),
      );
      local++;
      remote++;
    } else if (lengths[local + 1][remote] >= lengths[local][remote + 1]) {
      diff.add(
        _DiffLine(
          kind: _DiffLineKind.removed,
          text: localLines[local++],
          localLine: localLine++,
        ),
      );
    } else {
      diff.add(
        _DiffLine(
          kind: _DiffLineKind.added,
          text: remoteLines[remote++],
          remoteLine: remoteLine++,
        ),
      );
    }
  }
  while (local < localLines.length) {
    diff.add(
      _DiffLine(
        kind: _DiffLineKind.removed,
        text: localLines[local++],
        localLine: localLine++,
      ),
    );
  }
  while (remote < remoteLines.length) {
    diff.add(
      _DiffLine(
        kind: _DiffLineKind.added,
        text: remoteLines[remote++],
        remoteLine: remoteLine++,
      ),
    );
  }
  return diff;
}

TextStyle _diffTextStyle(BuildContext context) {
  return (Theme.of(context).textTheme.bodySmall ?? const TextStyle()).copyWith(
    fontFamily: 'monospace',
    fontSize: 12,
    height: 1.4,
  );
}

Color _diffRemovedBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF3D1F24)
    : const Color(0xFFFFEBE9);

Color _diffRemovedForeground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFFFB3AD)
    : const Color(0xFF82071E);

Color _diffAddedBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF16351F)
    : const Color(0xFFDAFBE1);

Color _diffAddedForeground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF7EE787)
    : const Color(0xFF116329);
