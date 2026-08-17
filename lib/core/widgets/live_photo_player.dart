import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class LivePhotoPlayer extends StatefulWidget {
  const LivePhotoPlayer({
    required this.posterFile,
    required this.motionFile,
    this.fit = BoxFit.contain,
    super.key,
  });

  final File posterFile;
  final File motionFile;
  final BoxFit fit;

  @override
  State<LivePhotoPlayer> createState() => _LivePhotoPlayerState();
}

class _LivePhotoPlayerState extends State<LivePhotoPlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  int _initializationGeneration = 0;

  @override
  void initState() {
    super.initState();
    _initialize(++_initializationGeneration);
  }

  @override
  void didUpdateWidget(covariant LivePhotoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.motionFile.path != widget.motionFile.path) {
      final previous = _controller;
      _controller = null;
      _ready = false;
      previous?.dispose();
      _initialize(++_initializationGeneration);
    }
  }

  Future<void> _initialize(int generation) async {
    final controller = VideoPlayerController.file(widget.motionFile);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (!mounted || generation != _initializationGeneration) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _ready = true;
      });
    } on Object {
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    _initializationGeneration++;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_ready || controller == null) {
      return Image.file(widget.posterFile, fit: widget.fit);
    }
    final size = controller.value.size;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: FittedBox(
          fit: widget.fit,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}
