import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

import '../../l10n/app_localizations.dart';

void applyDiaryImageWidth(
  QuillController controller,
  int offset,
  String width,
) {
  controller.compose(
    Delta()
      ..retain(offset)
      ..retain(1, {Attribute.width.key: width}),
    controller.selection,
    ChangeSource.local,
  );
}

class DiaryImageEmbedBuilder extends EmbedBuilder {
  const DiaryImageEmbedBuilder({
    this.targetOffset,
    this.targetKey,
    this.onTargetReady,
  });

  final int? targetOffset;
  final Key? targetKey;
  final VoidCallback? onTargetReady;

  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final node = embedContext.node;
    final source = node.value.data as String;
    final width = node.style.attributes[Attribute.width.key]?.value?.toString();
    final isSourceTarget = node.documentOffset == targetOffset;
    return _DiaryImageEmbed(
      key: isSourceTarget ? targetKey : null,
      controller: embedContext.controller,
      source: source,
      width: width,
      offset: node.documentOffset,
      readOnly: embedContext.readOnly,
      isSourceTarget: isSourceTarget,
      onTargetReady: isSourceTarget ? onTargetReady : null,
    );
  }
}

class _DiaryImageEmbed extends StatefulWidget {
  const _DiaryImageEmbed({
    required this.controller,
    required this.source,
    required this.width,
    required this.offset,
    required this.readOnly,
    required this.isSourceTarget,
    required this.onTargetReady,
    super.key,
  });

  final QuillController controller;
  final String source;
  final String? width;
  final int offset;
  final bool readOnly;
  final bool isSourceTarget;
  final VoidCallback? onTargetReady;

  @override
  State<_DiaryImageEmbed> createState() => _DiaryImageEmbedState();
}

enum _ResizeCorner { topLeft, topRight, bottomLeft, bottomRight }

class _DiaryImageEmbedState extends State<_DiaryImageEmbed> {
  static const _minimumPercentage = 25.0;

  bool _isSelected = false;
  bool _isDragging = false;
  double? _previewPercentage;

  @override
  void initState() {
    super.initState();
    _scheduleTargetReady();
  }

  @override
  void didUpdateWidget(covariant _DiaryImageEmbed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.offset != widget.offset) {
      _isSelected = false;
      _isDragging = false;
      _previewPercentage = null;
    } else if (!_isDragging && oldWidget.width != widget.width) {
      _previewPercentage = null;
    }
    if (!oldWidget.isSourceTarget && widget.isSourceTarget) {
      _scheduleTargetReady();
    }
  }

  void _scheduleTargetReady() {
    if (!widget.isSourceTarget || widget.onTargetReady == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onTargetReady?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final file = _resolveFile(widget.source);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final percentage =
            (_previewPercentage ??
                    _resolvePercentage(widget.width, availableWidth))
                .clamp(_minimumPercentage, 100)
                .toDouble();
        final imageWidth = availableWidth * percentage / 100;
        return Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            key: Key('diary-image-${widget.offset}'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.readOnly
                ? null
                : () => setState(() => _isSelected = !_isSelected),
            child: SizedBox(
              width: imageWidth,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    key: widget.isSourceTarget
                        ? const Key('diary-source-image-target')
                        : null,
                    decoration: BoxDecoration(
                      border: widget.isSourceTarget
                          ? Border.all(color: colors.primary, width: 3)
                          : _isSelected && !widget.readOnly
                          ? Border.all(color: colors.primary, width: 2)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: file == null
                          ? _MissingImage(label: l10n.editorImageMissing)
                          : ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 120),
                              child: Image.file(
                                file,
                                width: imageWidth,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                                errorBuilder: (context, error, stackTrace) {
                                  return _MissingImage(
                                    label: l10n.editorImageMissing,
                                  );
                                },
                              ),
                            ),
                    ),
                  ),
                  if (_isSelected && !widget.readOnly) ...[
                    PositionedDirectional(
                      top: 0,
                      start: 0,
                      child: _ResizeHandle(
                        key: Key(
                          'diary-image-handle-top-left-${widget.offset}',
                        ),
                        alignment: Alignment.topLeft,
                        label: l10n.editorAdjustImageSize,
                        onPanStart: (_) => _startResize(percentage),
                        onPanUpdate: (details) => _updateResize(
                          details.delta,
                          _ResizeCorner.topLeft,
                          availableWidth,
                        ),
                        onPanEnd: (_) => _finishResize(),
                        onPanCancel: _finishResize,
                      ),
                    ),
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: _ResizeHandle(
                        key: Key(
                          'diary-image-handle-top-right-${widget.offset}',
                        ),
                        alignment: Alignment.topRight,
                        label: l10n.editorAdjustImageSize,
                        onPanStart: (_) => _startResize(percentage),
                        onPanUpdate: (details) => _updateResize(
                          details.delta,
                          _ResizeCorner.topRight,
                          availableWidth,
                        ),
                        onPanEnd: (_) => _finishResize(),
                        onPanCancel: _finishResize,
                      ),
                    ),
                    PositionedDirectional(
                      bottom: 0,
                      start: 0,
                      child: _ResizeHandle(
                        key: Key(
                          'diary-image-handle-bottom-left-${widget.offset}',
                        ),
                        alignment: Alignment.bottomLeft,
                        label: l10n.editorAdjustImageSize,
                        onPanStart: (_) => _startResize(percentage),
                        onPanUpdate: (details) => _updateResize(
                          details.delta,
                          _ResizeCorner.bottomLeft,
                          availableWidth,
                        ),
                        onPanEnd: (_) => _finishResize(),
                        onPanCancel: _finishResize,
                      ),
                    ),
                    PositionedDirectional(
                      bottom: 0,
                      end: 0,
                      child: _ResizeHandle(
                        key: Key(
                          'diary-image-handle-bottom-right-${widget.offset}',
                        ),
                        alignment: Alignment.bottomRight,
                        label: l10n.editorAdjustImageSize,
                        onPanStart: (_) => _startResize(percentage),
                        onPanUpdate: (details) => _updateResize(
                          details.delta,
                          _ResizeCorner.bottomRight,
                          availableWidth,
                        ),
                        onPanEnd: (_) => _finishResize(),
                        onPanCancel: _finishResize,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _startResize(double percentage) {
    setState(() {
      _isDragging = true;
      _previewPercentage = percentage;
    });
  }

  void _updateResize(
    Offset delta,
    _ResizeCorner corner,
    double availableWidth,
  ) {
    if (!_isDragging || availableWidth <= 0) return;
    final horizontalDelta = switch (corner) {
      _ResizeCorner.topLeft || _ResizeCorner.bottomLeft => -delta.dx,
      _ResizeCorner.topRight || _ResizeCorner.bottomRight => delta.dx,
    };
    final verticalDelta = switch (corner) {
      _ResizeCorner.topLeft || _ResizeCorner.topRight => -delta.dy,
      _ResizeCorner.bottomLeft || _ResizeCorner.bottomRight => delta.dy,
    };
    final currentWidth = availableWidth * (_previewPercentage ?? 100) / 100;
    final nextWidth = (currentWidth + (horizontalDelta + verticalDelta) / 2)
        .clamp(availableWidth * _minimumPercentage / 100, availableWidth)
        .toDouble();
    setState(() => _previewPercentage = nextWidth / availableWidth * 100);
  }

  void _finishResize() {
    if (!_isDragging) return;
    final percentage = (_previewPercentage ?? 100).round().clamp(
      _minimumPercentage.round(),
      100,
    );
    setState(() {
      _isDragging = false;
      _previewPercentage = percentage.toDouble();
    });
    applyDiaryImageWidth(widget.controller, widget.offset, '$percentage%');
  }

  static File? _resolveFile(String source) {
    final uri = Uri.tryParse(source);
    if (uri == null) return null;
    if (uri.scheme == 'file') return File(uri.toFilePath());
    if (uri.scheme.isEmpty) return File(source);
    return null;
  }

  static double _resolvePercentage(String? value, double availableWidth) {
    final percentage = _tryParsePercentage(value);
    if (percentage != null) {
      return percentage.clamp(25, 100).toDouble();
    }

    final pixels = double.tryParse(value?.replaceAll('px', '') ?? '');
    if (pixels != null && availableWidth > 0) {
      return (pixels / availableWidth * 100).clamp(25, 100).toDouble();
    }
    return 100;
  }

  static double? _tryParsePercentage(String? value) {
    if (value == null || !value.endsWith('%')) return null;
    return double.tryParse(value.substring(0, value.length - 1));
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    required this.alignment,
    required this.label,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onPanCancel,
    super.key,
  });

  final Alignment alignment;
  final String label;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final GestureDragCancelCallback onPanCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: onPanStart,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          onPanCancel: onPanCancel,
          child: SizedBox.square(
            dimension: 32,
            child: Align(
              alignment: alignment,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border.all(color: colors.primary, width: 2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingImage extends StatelessWidget {
  const _MissingImage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 120,
      color: colors.surfaceContainerLow,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: colors.onSurfaceVariant),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
