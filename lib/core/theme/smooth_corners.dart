import 'package:flutter/material.dart';
import 'package:smooth_corner/smooth_corner.dart';

import 'package:smooth_corner/smooth_corner.dart' as smooth_corner;

export 'package:smooth_corner/smooth_corner.dart' hide SmoothClipRRect;

/// The Figma/iOS-style corner smoothing used throughout the app.
const double cornerSmoothing = 0.6;

/// Shared multiplier for all app corner radii.
const double cornerRadiusScale = 1.35;

/// Creates the app's standard smooth rectangular shape.
SmoothRectangleBorder smoothRectangleBorder({
  BorderRadiusGeometry borderRadius = BorderRadius.zero,
  BorderSide side = BorderSide.none,
  double smoothness = cornerSmoothing,
}) {
  return SmoothRectangleBorder(
    borderRadius: borderRadius * cornerRadiusScale,
    side: side,
    smoothness: smoothness,
  );
}

/// A smooth shape that keeps the [RoundedRectangleBorder] type expected by
/// Material components and existing integrations.
class SmoothRoundedRectangleBorder extends RoundedRectangleBorder {
  const SmoothRoundedRectangleBorder({
    super.side,
    super.borderRadius,
    this.smoothness = cornerSmoothing,
  });

  final double smoothness;

  SmoothRectangleBorder get _delegate => SmoothRectangleBorder(
    borderRadius: borderRadius * cornerRadiusScale,
    side: side,
    smoothness: smoothness,
  );

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _delegate.getOuterPath(rect, textDirection: textDirection);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _delegate.getInnerPath(rect, textDirection: textDirection);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    _delegate.paint(canvas, rect, textDirection: textDirection);
  }

  @override
  SmoothRoundedRectangleBorder copyWith({
    BorderSide? side,
    BorderRadiusGeometry? borderRadius,
  }) {
    return SmoothRoundedRectangleBorder(
      side: side ?? this.side,
      borderRadius: borderRadius ?? this.borderRadius,
      smoothness: smoothness,
    );
  }

  @override
  SmoothRoundedRectangleBorder scale(double t) {
    return SmoothRoundedRectangleBorder(
      side: side.scale(t),
      borderRadius: borderRadius * t,
      smoothness: smoothness,
    );
  }

  @override
  int get hashCode => Object.hash(super.hashCode, smoothness);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is SmoothRoundedRectangleBorder &&
            other.side == side &&
            other.borderRadius == borderRadius &&
            other.smoothness == smoothness);
  }
}

/// A [BoxDecoration] that uses a smooth corner path when it has rounded
/// rectangular corners, while retaining the normal BoxDecoration behavior for
/// circles and decorations that need non-uniform borders or blend modes.
class SmoothBoxDecoration extends BoxDecoration {
  const SmoothBoxDecoration({
    super.color,
    super.image,
    super.border,
    super.borderRadius,
    super.boxShadow,
    super.gradient,
    super.backgroundBlendMode,
    super.shape,
    this.smoothness = cornerSmoothing,
  });

  final double smoothness;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _SmoothBoxDecorationPainter(this, onChanged);
  }

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) {
    final borderRadius = this.borderRadius;
    if (_canSmooth(this)) {
      return smoothRectangleBorder(
        borderRadius: borderRadius!,
        smoothness: smoothness,
      ).getOuterPath(rect, textDirection: textDirection);
    }
    return super.getClipPath(rect, textDirection);
  }
}

/// A smooth clip whose radius follows the app-wide corner scale.
class SmoothClipRRect extends StatelessWidget {
  const SmoothClipRRect({
    super.key,
    this.smoothness = cornerSmoothing,
    this.borderRadius = BorderRadius.zero,
    this.side = BorderSide.none,
    required this.child,
  });

  final BorderRadius borderRadius;
  final double smoothness;
  final BorderSide side;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return smooth_corner.SmoothClipRRect(
      smoothness: smoothness,
      borderRadius: borderRadius * cornerRadiusScale,
      side: side,
      child: child,
    );
  }
}

class _SmoothBoxDecorationPainter extends BoxPainter {
  _SmoothBoxDecorationPainter(this.decoration, VoidCallback? onChanged)
    : super(onChanged);

  final SmoothBoxDecoration decoration;
  BoxPainter? _delegate;
  BoxPainter? _smoothDelegate;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final borderSide = _uniformBorderSide(decoration.border);
    final borderRadius = decoration.borderRadius;
    if (!_canSmooth(decoration)) {
      (_delegate ??= _standardPainter()).paint(canvas, offset, configuration);
      return;
    }

    (_smoothDelegate ??= _smoothPainter(
      borderRadius!,
      borderSide!,
    )).paint(canvas, offset, configuration);
  }

  BoxPainter _smoothPainter(
    BorderRadiusGeometry borderRadius,
    BorderSide borderSide,
  ) {
    return ShapeDecoration(
      color: decoration.color,
      image: decoration.image,
      gradient: decoration.gradient,
      shadows: decoration.boxShadow,
      shape: smoothRectangleBorder(
        borderRadius: borderRadius,
        side: borderSide,
        smoothness: decoration.smoothness,
      ),
    ).createBoxPainter(onChanged);
  }

  BoxPainter _standardPainter() {
    return BoxDecoration(
      color: decoration.color,
      image: decoration.image,
      border: decoration.border,
      borderRadius: decoration.borderRadius,
      boxShadow: decoration.boxShadow,
      gradient: decoration.gradient,
      backgroundBlendMode: decoration.backgroundBlendMode,
      shape: decoration.shape,
    ).createBoxPainter(onChanged);
  }
}

bool _canSmooth(SmoothBoxDecoration decoration) {
  return decoration.shape == BoxShape.rectangle &&
      decoration.borderRadius != null &&
      decoration.borderRadius != BorderRadius.zero &&
      decoration.backgroundBlendMode == null &&
      _uniformBorderSide(decoration.border) != null;
}

BorderSide? _uniformBorderSide(BoxBorder? border) {
  if (border == null) return BorderSide.none;
  if (border is Border) {
    final side = border.top;
    if (border.right == side && border.bottom == side && border.left == side) {
      return side;
    }
  }
  return null;
}

/// An [OutlineInputBorder] backed by the same smooth corner path.
class SmoothOutlineInputBorder extends OutlineInputBorder {
  const SmoothOutlineInputBorder({
    super.borderSide,
    super.borderRadius,
    super.gapPadding,
    this.smoothness = cornerSmoothing,
  });

  final double smoothness;

  SmoothRectangleBorder get _shape => smoothRectangleBorder(
    borderRadius: borderRadius,
    side: borderSide,
    smoothness: smoothness,
  );

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _shape.getOuterPath(rect, textDirection: textDirection);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _shape.getInnerPath(rect, textDirection: textDirection);
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    // Preserve the label cut-out behavior for floating labels. The normal
    // path is only used while the outline is uninterrupted.
    if (gapStart != null && gapExtent > 0 && gapPercentage > 0) {
      super.paint(
        canvas,
        rect,
        gapStart: gapStart,
        gapExtent: gapExtent,
        gapPercentage: gapPercentage,
        textDirection: textDirection,
      );
      return;
    }
    _shape.paint(canvas, rect, textDirection: textDirection);
  }

  @override
  SmoothOutlineInputBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
    double? smoothness,
  }) {
    return SmoothOutlineInputBorder(
      borderSide: borderSide ?? this.borderSide,
      borderRadius: borderRadius ?? this.borderRadius,
      gapPadding: gapPadding ?? this.gapPadding,
      smoothness: smoothness ?? this.smoothness,
    );
  }

  @override
  SmoothOutlineInputBorder scale(double t) {
    return SmoothOutlineInputBorder(
      borderSide: borderSide.scale(t),
      borderRadius: borderRadius * t,
      gapPadding: gapPadding * t,
      smoothness: smoothness,
    );
  }
}
