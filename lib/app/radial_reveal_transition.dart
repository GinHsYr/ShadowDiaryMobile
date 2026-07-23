import 'dart:math' as math;

import 'package:flutter/material.dart';

class RadialRevealTransition extends StatefulWidget {
  const RadialRevealTransition({
    required this.animation,
    required this.origin,
    required this.child,
    this.minimumRadius = 24,
    super.key,
  });

  final Animation<double> animation;
  final Offset origin;
  final Widget child;
  final double minimumRadius;

  @override
  State<RadialRevealTransition> createState() => _RadialRevealTransitionState();
}

class _RadialRevealTransitionState extends State<RadialRevealTransition> {
  late CurvedAnimation _curvedAnimation;

  @override
  void initState() {
    super.initState();
    _createCurvedAnimation();
  }

  @override
  void didUpdateWidget(RadialRevealTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _curvedAnimation.dispose();
      _createCurvedAnimation();
    }
  }

  void _createCurvedAnimation() {
    _curvedAnimation = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _curvedAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _curvedAnimation,
      child: RepaintBoundary(child: widget.child),
      builder: (context, child) {
        return ClipPath(
          key: const Key('search-radial-reveal-clip'),
          clipper: RadialRevealClipper(
            origin: widget.origin,
            progress: _curvedAnimation.value,
            minimumRadius: widget.minimumRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      },
    );
  }
}

class RadialRevealClipper extends CustomClipper<Path> {
  const RadialRevealClipper({
    required this.origin,
    required this.progress,
    this.minimumRadius = 24,
  });

  final Offset origin;
  final double progress;
  final double minimumRadius;

  @override
  Path getClip(Size size) {
    final resolvedOrigin = Offset(
      origin.dx.clamp(0.0, size.width),
      origin.dy.clamp(0.0, size.height),
    );
    final farthestX = math.max(
      resolvedOrigin.dx,
      size.width - resolvedOrigin.dx,
    );
    final farthestY = math.max(
      resolvedOrigin.dy,
      size.height - resolvedOrigin.dy,
    );
    final maximumRadius = math.sqrt(
      farthestX * farthestX + farthestY * farthestY,
    );
    final radius =
        minimumRadius +
        (maximumRadius - minimumRadius) * progress.clamp(0.0, 1.0);
    return Path()
      ..addOval(Rect.fromCircle(center: resolvedOrigin, radius: radius));
  }

  @override
  bool shouldReclip(RadialRevealClipper oldClipper) {
    return origin != oldClipper.origin ||
        progress != oldClipper.progress ||
        minimumRadius != oldClipper.minimumRadius;
  }
}
