import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../core/services/diary_image_store.dart';
import '../../core/theme/smooth_corners.dart';
import '../../core/widgets/live_photo_badge.dart';
import '../../core/widgets/live_photo_player.dart';
import '../../l10n/app_localizations.dart';

Future<void> showDiaryImageViewer(
  BuildContext context, {
  required List<String> images,
  required int initialIndex,
}) {
  if (images.isEmpty) return Future.value();
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      reverseTransitionDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _DiaryImageViewer(
          images: images,
          initialIndex: initialIndex.clamp(0, images.length - 1),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _DiaryImageViewer extends StatefulWidget {
  const _DiaryImageViewer({required this.images, required this.initialIndex});

  final List<String> images;
  final int initialIndex;

  @override
  State<_DiaryImageViewer> createState() => _DiaryImageViewerState();
}

class _DiaryImageViewerState extends State<_DiaryImageViewer> {
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
    final currentFile =
        diaryImageStoreOf(
          context,
        ).fileForSource(widget.images[_currentIndex]) ??
        File(widget.images[_currentIndex]);
    final currentMotionFile = diaryImageStoreOf(
      context,
    ).motionFileForSource(widget.images[_currentIndex]);
    return Material(
      key: const Key('diary-image-viewer'),
      color: Colors.black,
      child: Stack(
        children: [
          PhotoViewGallery.builder(
            itemCount: widget.images.length,
            pageController: _pageController,
            allowImplicitScrolling: true,
            backgroundDecoration: const SmoothBoxDecoration(
              color: Colors.black,
            ),
            onPageChanged: (index) => setState(() => _currentIndex = index),
            builder: (context, index) {
              final file =
                  diaryImageStoreOf(
                    context,
                  ).fileForSource(widget.images[index]) ??
                  File(widget.images[index]);
              final motionFile = diaryImageStoreOf(
                context,
              ).motionFileForSource(widget.images[index]);
              if (motionFile != null && motionFile.existsSync()) {
                return PhotoViewGalleryPageOptions.customChild(
                  child: LivePhotoPlayer(
                    posterFile: file,
                    motionFile: motionFile,
                  ),
                  semanticLabel: l10n.archiveImagePosition(
                    index + 1,
                    widget.images.length,
                  ),
                  minScale: PhotoViewComputedScale.contained,
                  initialScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 4,
                );
              }
              return PhotoViewGalleryPageOptions(
                imageProvider: FileImage(file),
                semanticLabel: l10n.archiveImagePosition(
                  index + 1,
                  widget.images.length,
                ),
                minScale: PhotoViewComputedScale.contained,
                initialScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 4,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    l10n.editorImageMissing,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton.filledTonal(
                  key: const Key('diary-image-viewer-close'),
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
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LivePhotoBadge(
                  file: currentFile,
                  motionFile: currentMotionFile,
                  iconOnly: false,
                ),
              ),
            ),
          ),
          if (widget.images.length > 1)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: DecoratedBox(
                    decoration: SmoothBoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.images.length}',
                        key: const Key('diary-image-viewer-counter'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
