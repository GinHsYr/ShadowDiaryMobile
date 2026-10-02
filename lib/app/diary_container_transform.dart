import 'package:flutter/material.dart';

import '../features/home/home_page.dart';

class DiaryContainerTransform extends StatelessWidget {
  const DiaryContainerTransform({
    required this.animation,
    required this.selection,
    required this.child,
    super.key,
  });

  final Animation<double> animation;
  final HomeCalendarDateSelection selection;
  final Widget child;

  static const openDuration = Duration(milliseconds: 600);
  static const closeDuration = Duration(milliseconds: 380);
  static const curve = Cubic(0.32, 0.72, 0, 1);

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: SizedBox.expand(child: child),
      );
    }

    final progressAnimation = CurvedAnimation(
      parent: animation,
      curve: curve,
      reverseCurve: Curves.easeInCubic,
    );

    return AnimatedBuilder(
      animation: progressAnimation,
      child: child,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final viewport = Offset.zero & size;
            final progress = progressAnimation.value;
            final localRect = _localSelectionRect(context, selection.rect!);
            final rect = Rect.lerp(localRect, viewport, progress)!;
            final radius = selection.borderRadius * (1 - progress);
            final contentOpacity = Curves.easeOut.transform(
              ((progress - 0.8) / 0.2).clamp(0.0, 1.0),
            );
            final surfaceColor = Theme.of(context).colorScheme.surface;

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fromRect(
                  rect: rect,
                  child: ClipRRect(
                    key: const Key('diary-container-panel'),
                    borderRadius: BorderRadius.circular(radius),
                    child: ColoredBox(color: surfaceColor),
                  ),
                ),
                Positioned.fromRect(
                  rect: rect,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: size.width,
                      maxWidth: size.width,
                      minHeight: size.height,
                      maxHeight: size.height,
                      child: Transform.translate(
                        offset: -rect.topLeft,
                        child: SizedBox(
                          width: size.width,
                          height: size.height,
                          child: Opacity(
                            key: const Key('diary-container-content'),
                            opacity: contentOpacity,
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Rect _localSelectionRect(BuildContext context, Rect globalRect) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return globalRect;
    return Rect.fromPoints(
      renderObject.globalToLocal(globalRect.topLeft),
      renderObject.globalToLocal(globalRect.bottomRight),
    );
  }
}
