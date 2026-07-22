import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../core/media/media_library.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../l10n/app_localizations.dart';

typedef OpenMediaSource = Future<Object?> Function(MediaItem item);

enum _MediaFilter { all, diary, archive }

class MediaPage extends ConsumerStatefulWidget {
  const MediaPage({this.onOpenSource, super.key});

  final OpenMediaSource? onOpenSource;

  @override
  ConsumerState<MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends ConsumerState<MediaPage> {
  _MediaFilter _filter = _MediaFilter.all;

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(mediaLibraryProvider);
    return SafeArea(
      key: const Key('media-page-safe-area'),
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columnCount = constraints.maxWidth >= 840
              ? 4
              : constraints.maxWidth >= 560
              ? 3
              : 2;
          return CustomScrollView(
            key: const Key('media-scroll-view'),
            slivers: [
              SliverToBoxAdapter(
                child: _MediaHeader(
                  library: library.value,
                  filter: _filter,
                  onFilterChanged: (filter) {
                    setState(() => _filter = filter);
                  },
                ),
              ),
              ...library.when(
                loading: () => const <Widget>[
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _MediaLoadingState(),
                  ),
                ],
                error: (error, stackTrace) => <Widget>[
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _MediaErrorState(
                      onRetry: () => ref.invalidate(mediaLibraryProvider),
                    ),
                  ),
                ],
                data: (value) {
                  if (value.items.isEmpty) {
                    return const <Widget>[
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _MediaEmptyState(),
                      ),
                    ];
                  }
                  final visibleItems = _visibleItems(value);
                  if (visibleItems.isEmpty) {
                    return const <Widget>[
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _MediaFilteredEmptyState(),
                      ),
                    ];
                  }
                  return <Widget>[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        AppSpacing.sm,
                        AppSpacing.sm,
                        104,
                      ),
                      sliver: SliverMasonryGrid.count(
                        key: const Key('media-masonry-grid'),
                        crossAxisCount: columnCount,
                        mainAxisSpacing: AppSpacing.xs,
                        crossAxisSpacing: AppSpacing.xs,
                        childCount: visibleItems.length,
                        itemBuilder: (context, index) {
                          final item = visibleItems[index];
                          return _MediaImageTile(
                            item: item,
                            onTap: () => _openViewer(visibleItems, index),
                          );
                        },
                      ),
                    ),
                  ];
                },
              ),
            ],
          );
        },
      ),
    );
  }

  List<MediaItem> _visibleItems(MediaLibrary library) {
    final sourceType = switch (_filter) {
      _MediaFilter.all => null,
      _MediaFilter.diary => MediaSourceType.diary,
      _MediaFilter.archive => MediaSourceType.archive,
    };
    if (sourceType == null) return library.items;
    return library.items
        .where((item) => item.sourceType == sourceType)
        .toList(growable: false);
  }

  Future<void> _openViewer(List<MediaItem> items, int initialIndex) async {
    final source = await showMediaImageViewer(
      context,
      items: items,
      initialIndex: initialIndex,
    );
    if (!mounted || source == null) return;
    await widget.onOpenSource?.call(source);
  }
}

class _MediaHeader extends StatelessWidget {
  const _MediaHeader({
    required this.library,
    required this.filter,
    required this.onFilterChanged,
  });

  final MediaLibrary? library;
  final _MediaFilter filter;
  final ValueChanged<_MediaFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final total = library?.items.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.navigationMedia,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (total != null)
                Text(
                  l10n.mediaImageTotal(total),
                  key: const Key('media-total-count'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (library != null) ...[
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _MediaFilterChip(
                    key: const Key('media-filter-all'),
                    label: l10n.mediaFilterAll,
                    count: library!.items.length,
                    icon: Icons.grid_view_rounded,
                    selected: filter == _MediaFilter.all,
                    onSelected: () => onFilterChanged(_MediaFilter.all),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _MediaFilterChip(
                    key: const Key('media-filter-diary'),
                    label: l10n.mediaFilterDiary,
                    count: library!.diaryCount,
                    icon: Icons.menu_book_outlined,
                    selected: filter == _MediaFilter.diary,
                    onSelected: () => onFilterChanged(_MediaFilter.diary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _MediaFilterChip(
                    key: const Key('media-filter-archive'),
                    label: l10n.mediaFilterArchive,
                    count: library!.archiveCount,
                    icon: Icons.folder_open_outlined,
                    selected: filter == _MediaFilter.archive,
                    onSelected: () => onFilterChanged(_MediaFilter.archive),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MediaFilterChip extends StatelessWidget {
  const _MediaFilterChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(icon, size: 17),
      label: Text('$label  $count'),
      onSelected: (_) => onSelected(),
    );
  }
}

class _MediaImageTile extends StatelessWidget {
  const _MediaImageTile({required this.item, required this.onTap});

  final MediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sourceLabel = item.sourceType == MediaSourceType.diary
        ? l10n.mediaFilterDiary
        : l10n.mediaFilterArchive;
    return Semantics(
      button: true,
      label: '$sourceLabel · ${_mediaSourceTitle(item, l10n)}',
      child: Material(
        key: Key('media-item-${item.id}'),
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            alignment: AlignmentDirectional.bottomEnd,
            children: [
              Image.file(
                _mediaFile(item.imageSource),
                width: double.infinity,
                fit: BoxFit.fitWidth,
                filterQuality: FilterQuality.medium,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return const AspectRatio(
                    aspectRatio: 1,
                    child: _MediaImagePlaceholder(loading: true),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return AspectRatio(
                    aspectRatio: 1,
                    child: _MediaImagePlaceholder(
                      label: l10n.mediaImageMissing,
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.58),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(
                      item.sourceType == MediaSourceType.diary
                          ? Icons.menu_book_rounded
                          : Icons.folder_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaImagePlaceholder extends StatelessWidget {
  const _MediaImagePlaceholder({this.label, this.loading = false});

  final String? label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHigh,
      child: Center(
        child: loading
            ? SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.onSurfaceVariant,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    color: colors.onSurfaceVariant,
                  ),
                  if (label != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      label!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _MediaLoadingState extends StatelessWidget {
  const _MediaLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 88),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _MediaErrorState extends StatelessWidget {
  const _MediaErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        88,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.mediaLoadError, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaEmptyState extends StatelessWidget {
  const _MediaEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        88,
      ),
      child: Center(
        child: EmptyStateCard(
          icon: Icons.photo_library_outlined,
          title: l10n.mediaEmptyTitle,
          body: l10n.mediaEmptyBody,
        ),
      ),
    );
  }
}

class _MediaFilteredEmptyState extends StatelessWidget {
  const _MediaFilteredEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 88),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_alt_off_outlined,
              size: 38,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppLocalizations.of(context).mediaFilteredEmpty,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

Future<MediaItem?> showMediaImageViewer(
  BuildContext context, {
  required List<MediaItem> items,
  required int initialIndex,
}) {
  if (items.isEmpty) return Future.value();
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return Navigator.of(context, rootNavigator: true).push<MediaItem>(
    PageRouteBuilder<MediaItem>(
      opaque: true,
      transitionDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      reverseTransitionDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _MediaImageViewer(
          items: items,
          initialIndex: initialIndex.clamp(0, items.length - 1),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _MediaImageViewer extends StatefulWidget {
  const _MediaImageViewer({required this.items, required this.initialIndex});

  final List<MediaItem> items;
  final int initialIndex;

  @override
  State<_MediaImageViewer> createState() => _MediaImageViewerState();
}

class _MediaImageViewerState extends State<_MediaImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentItem = widget.items[_currentIndex];
    return Material(
      key: const Key('media-image-viewer'),
      color: Colors.black,
      child: Stack(
        children: [
          PhotoViewGallery.builder(
            itemCount: widget.items.length,
            pageController: _pageController,
            allowImplicitScrolling: true,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            onPageChanged: (index) => setState(() => _currentIndex = index),
            builder: (context, index) {
              final item = widget.items[index];
              return PhotoViewGalleryPageOptions(
                imageProvider: FileImage(_mediaFile(item.imageSource)),
                semanticLabel: l10n.archiveImagePosition(
                  index + 1,
                  widget.items.length,
                ),
                minScale: PhotoViewComputedScale.contained,
                initialScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 4,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white70,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.mediaImageMissing,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton.filledTonal(
                  key: const Key('media-image-viewer-close'),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _MediaViewerSourceCard(
                item: currentItem,
                index: _currentIndex,
                total: widget.items.length,
                onOpenSource: () => Navigator.of(context).pop(currentItem),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaViewerSourceCard extends StatelessWidget {
  const _MediaViewerSourceCard({
    required this.item,
    required this.index,
    required this.total,
    required this.onOpenSource,
  });

  final MediaItem item;
  final int index;
  final int total;
  final VoidCallback onOpenSource;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final sourceLabel = item.sourceType == MediaSourceType.diary
        ? l10n.mediaFilterDiary
        : l10n.mediaFilterArchive;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    item.sourceType == MediaSourceType.diary
                        ? Icons.menu_book_rounded
                        : Icons.folder_rounded,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      sourceLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${index + 1} / $total',
                    key: const Key('media-image-viewer-counter'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _mediaSourceTitle(item, l10n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat.yMMMd(locale).format(item.sourceDate),
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonalIcon(
                    key: const Key('media-view-source-button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onPressed: onOpenSource,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(l10n.mediaViewSource),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

File _mediaFile(String source) {
  final uri = Uri.tryParse(source);
  if (uri != null && uri.scheme == 'file') {
    try {
      return File(uri.toFilePath());
    } on UnsupportedError {
      return File(source);
    }
  }
  return File(source);
}

String _mediaSourceTitle(MediaItem item, AppLocalizations l10n) {
  if (item.sourceTitle.isNotEmpty) return item.sourceTitle;
  return item.sourceType == MediaSourceType.diary
      ? l10n.mediaUntitledDiary
      : l10n.navigationArchives;
}
