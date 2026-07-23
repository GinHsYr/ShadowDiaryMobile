import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/archives/archive.dart';
import '../../core/archives/archive_repository.dart';
import '../../core/archives/archive_search.dart';
import '../../core/archives/archive_sort.dart';
import '../../core/services/archive_image_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../l10n/app_localizations.dart';

typedef OpenNewArchive = Future<Object?> Function();
typedef OpenArchiveEditor = Future<Object?> Function(String archiveId);

class ArchivesPage extends ConsumerStatefulWidget {
  const ArchivesPage({this.onAddArchive, this.onEditArchive, super.key});

  final OpenNewArchive? onAddArchive;
  final OpenArchiveEditor? onEditArchive;

  @override
  ConsumerState<ArchivesPage> createState() => _ArchivesPageState();
}

class _ArchivesPageState extends ConsumerState<ArchivesPage> {
  static const _alphabet = <String>[
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    '#',
  ];

  final Set<String> _removingIds = {};
  final Map<String, GlobalKey> _groupKeys = {};
  final TextEditingController _searchController = TextEditingController();
  String? _selectedInitial;
  String _searchQuery = '';
  bool _isSearchExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final archives = ref.watch(archiveListProvider);
    return SafeArea(
      key: const Key('archives-page-safe-area'),
      bottom: false,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: _motionDuration(context, 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: archives.when(
                loading: () => _ArchiveStaticLayout(
                  key: const ValueKey('archives-loading'),
                  header: _buildHeader(context),
                  child: const CircularProgressIndicator(),
                ),
                error: (error, stackTrace) => _ArchiveStaticLayout(
                  key: const ValueKey('archives-error'),
                  header: _buildHeader(context),
                  child: _ArchiveErrorState(
                    onRetry: () => ref.invalidate(archiveListProvider),
                  ),
                ),
                data: (values) {
                  if (values.isEmpty) {
                    return _ArchiveStaticLayout(
                      key: const ValueKey('archives-empty'),
                      header: _buildHeader(context),
                      child: const _ArchivesEmptyState(),
                    );
                  }
                  final matches = searchArchives(values, _searchQuery);
                  return _buildArchiveList(
                    context,
                    groupAndSortArchives(matches),
                  );
                },
              ),
            ),
          ),
          if (widget.onAddArchive != null)
            PositionedDirectional(
              end: AppSpacing.md,
              bottom: 92,
              child: FloatingActionButton(
                key: const Key('archives-add-button'),
                heroTag: 'archives-add-button',
                shape: const CircleBorder(),
                tooltip: AppLocalizations.of(context).archiveAdd,
                onPressed: _openNew,
                child: const Icon(Icons.add_rounded),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.navigationArchives,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              key: const Key('archive-search-button'),
              tooltip: _isSearchExpanded
                  ? l10n.archiveSearchClose
                  : l10n.archiveSearch,
              onPressed: _toggleSearch,
              icon: AnimatedSwitcher(
                duration: _motionDuration(context, 160),
                child: Icon(
                  _isSearchExpanded
                      ? Icons.close_rounded
                      : Icons.search_rounded,
                  key: ValueKey(_isSearchExpanded),
                ),
              ),
            ),
          ],
        ),
        AnimatedSwitcher(
          duration: _motionDuration(context, 200),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: _isSearchExpanded
              ? Padding(
                  key: const Key('archive-search-area'),
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: TextField(
                    key: const Key('archive-search-field'),
                    controller: _searchController,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: l10n.archiveSearchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              key: const Key('archive-search-clear-button'),
                              tooltip: l10n.archiveSearchClear,
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.cancel_rounded),
                            ),
                      filled: true,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                )
              : const SizedBox(key: ValueKey('archive-search-collapsed')),
        ),
      ],
    );
  }

  Widget _buildArchiveList(BuildContext context, List<ArchiveGroup> groups) {
    final availableInitials = groups.map((group) => group.initial).toSet();
    _groupKeys.removeWhere(
      (initial, key) => !availableInitials.contains(initial),
    );
    final selectedInitial = groups.isEmpty
        ? null
        : availableInitials.contains(_selectedInitial)
        ? _selectedInitial!
        : groups.first.initial;
    final showAlphabetRail = !_isSearchExpanded;
    final children = <Widget>[_buildHeader(context)];
    if (groups.isEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            96,
            AppSpacing.lg,
            112,
          ),
          child: _ArchiveSearchEmptyState(),
        ),
      );
    } else {
      for (final group in groups) {
        final groupKey = _groupKeys.putIfAbsent(group.initial, GlobalKey.new);
        children.add(
          _ArchiveGroupHeader(key: groupKey, initial: group.initial),
        );
        for (final archive in group.archives) {
          final isRemoving = _removingIds.contains(archive.id);
          children.add(
            AnimatedSize(
              duration: _motionDuration(context, 220),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: isRemoving
                  ? const SizedBox(width: double.infinity)
                  : _ArchiveListRow(
                      archive: archive,
                      onTap: widget.onEditArchive == null
                          ? null
                          : () => _openEditor(archive.id),
                      onDelete: () => _confirmAndDelete(archive),
                    ),
            ),
          );
        }
      }
      children.add(const SizedBox(height: 112));
    }

    return Stack(
      key: const ValueKey('archives-data'),
      children: [
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                AppSpacing.md,
                showAlphabetRail ? 46 : AppSpacing.md,
                0,
              ),
              sliver: SliverList.list(children: children),
            ),
          ],
        ),
        if (showAlphabetRail && selectedInitial != null)
          PositionedDirectional(
            top: 72,
            end: 4,
            bottom: 112,
            child: Center(
              child: _AlphabetRail(
                alphabet: _alphabet,
                availableInitials: availableInitials,
                selectedInitial: selectedInitial,
                onSelected: _jumpToInitial,
              ),
            ),
          ),
      ],
    );
  }

  void _toggleSearch() {
    if (_isSearchExpanded) {
      _searchController.clear();
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _isSearchExpanded = false;
        _searchQuery = '';
      });
      return;
    }

    setState(() => _isSearchExpanded = true);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  Future<void> _jumpToInitial(String initial) async {
    final targetContext = _groupKeys[initial]?.currentContext;
    if (targetContext == null) return;
    setState(() => _selectedInitial = initial);
    await Scrollable.ensureVisible(
      targetContext,
      duration: _motionDuration(context, 260),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  Future<void> _openNew() async {
    final result = await widget.onAddArchive?.call();
    if (result == true) ref.invalidate(archiveListProvider);
  }

  Future<void> _openEditor(String archiveId) async {
    final result = await widget.onEditArchive?.call(archiveId);
    if (result == true) ref.invalidate(archiveListProvider);
  }

  Future<void> _confirmAndDelete(Archive archive) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.archiveDeleteTitle),
        content: Text(l10n.archiveDeleteMessage(archive.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('archive-delete-confirm-button'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repository = ref.read(archiveRepositoryProvider);
    final imageService = ref.read(archiveImageServiceProvider);
    setState(() => _removingIds.add(archive.id));
    await Future<void>.delayed(_motionDuration(context, 220));
    try {
      await repository.delete(archive.id);
      await imageService.deleteManagedImages([
        ?archive.mainImage,
        ...archive.images,
      ]);
      if (mounted) ref.invalidate(archiveListProvider);
    } on Object {
      if (!mounted) return;
      setState(() => _removingIds.remove(archive.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.archiveDeleteError)));
    }
  }
}

class _ArchiveStaticLayout extends StatelessWidget {
  const _ArchiveStaticLayout({
    required this.header,
    required this.child,
    super.key,
  });

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Column(
        children: [
          header,
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  88,
                ),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivesEmptyState extends StatelessWidget {
  const _ArchivesEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppEmptyState(
      key: const Key('archives-empty-state'),
      icon: Icons.folder_open_rounded,
      title: l10n.archivesEmptyTitle,
      body: l10n.archivesEmptyBody,
    );
  }
}

class _ArchiveSearchEmptyState extends StatelessWidget {
  const _ArchiveSearchEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppEmptyState(
      key: const Key('archives-search-empty-state'),
      icon: Icons.search_off_rounded,
      title: l10n.archiveSearchNoResultsTitle,
      body: l10n.archiveSearchNoResultsBody,
    );
  }
}

class _ArchiveGroupHeader extends StatelessWidget {
  const _ArchiveGroupHeader({required this.initial, super.key});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(0, 18, 0, 5),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            initial,
            key: Key('archive-group-$initial'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArchiveListRow extends StatelessWidget {
  const _ArchiveListRow({
    required this.archive,
    required this.onTap,
    required this.onDelete,
  });

  final Archive archive;
  final VoidCallback? onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final aliasSeparator = Localizations.localeOf(context).languageCode == 'zh'
        ? '、'
        : ', ';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Slidable(
        key: Key('archive-card-${archive.id}'),
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              key: Key('archive-swipe-delete-${archive.id}'),
              onPressed: (_) => onDelete(),
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              icon: Icons.delete_outline_rounded,
              label: l10n.delete,
              borderRadius: BorderRadius.circular(16),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(
                children: [
                  _ArchiveAvatar(archive: archive),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          archive.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (archive.aliases.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            archive.aliases.join(aliasSeparator),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.55),
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      archive.type == ArchiveType.person
                          ? l10n.archiveTypePerson
                          : l10n.archiveTypeOther,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
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

class _ArchiveAvatar extends StatelessWidget {
  const _ArchiveAvatar({required this.archive});

  final Archive archive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final normalizedName = archive.name.trim();
    final fallbackCharacter = normalizedName.isEmpty
        ? '#'
        : String.fromCharCode(normalizedName.runes.first);
    final fallback = Center(
      child: Text(
        fallbackCharacter,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: colors.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return Container(
      key: Key('archive-avatar-${archive.id}'),
      width: 54,
      height: 54,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: archive.mainImage == null
          ? fallback
          : Image.file(
              File(archive.mainImage!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback,
            ),
    );
  }
}

class _AlphabetRail extends StatelessWidget {
  const _AlphabetRail({
    required this.alphabet,
    required this.availableInitials,
    required this.selectedInitial,
    required this.onSelected,
  });

  final List<String> alphabet;
  final Set<String> availableInitials;
  final String selectedInitial;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('archive-alphabet-rail'),
      width: 28,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemHeight = (constraints.maxHeight / alphabet.length).clamp(
            12.0,
            18.0,
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final initial in alphabet)
                SizedBox(
                  width: 24,
                  height: itemHeight,
                  child: InkWell(
                    key: Key('archive-index-$initial'),
                    customBorder: const CircleBorder(),
                    onTap: availableInitials.contains(initial)
                        ? () => onSelected(initial)
                        : null,
                    child: Center(
                      child: AnimatedContainer(
                        duration: _motionDuration(context, 140),
                        width: 17,
                        height: 17,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selectedInitial == initial
                              ? colors.primary
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          initial,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: selectedInitial == initial
                                    ? colors.onPrimary
                                    : availableInitials.contains(initial)
                                    ? colors.onSurfaceVariant
                                    : colors.onSurfaceVariant.withValues(
                                        alpha: 0.32,
                                      ),
                                fontSize: 9,
                                height: 1,
                                fontWeight: selectedInitial == initial
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ArchiveErrorState extends StatelessWidget {
  const _ArchiveErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 40,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.archiveLoadError, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n.retry),
        ),
      ],
    );
  }
}

Duration _motionDuration(BuildContext context, int milliseconds) {
  return MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);
}
