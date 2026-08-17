import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../l10n/app_localizations.dart';
import '../services/motion_photo_support.dart';

final Map<String, Future<bool>> _livePhotoCache = <String, Future<bool>>{};

Future<bool> isLivePhotoFile(File file, {File? motionFile}) {
  final resolvedMotion = motionFile ?? _inferredMotionFile(file);
  final cacheKey = '${file.path}|${resolvedMotion.path}';
  return _livePhotoCache.putIfAbsent(cacheKey, () async {
    if (await resolvedMotion.exists()) return true;
    return _detectAnimatedImage(file);
  });
}

File _inferredMotionFile(File file) {
  final stem = p.basenameWithoutExtension(file.path);
  return File(p.join(p.dirname(file.path), '$stem$motionPhotoFileSuffix'));
}

Future<bool> _detectAnimatedImage(File file) async {
  try {
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    final isAnimated = codec.frameCount > 1;
    codec.dispose();
    return isAnimated;
  } on Object {
    return false;
  }
}

class LivePhotoBadge extends StatelessWidget {
  const LivePhotoBadge({
    required this.file,
    this.motionFile,
    this.iconOnly = true,
    super.key,
  });

  final File file;
  final File? motionFile;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: isLivePhotoFile(file, motionFile: motionFile),
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        final label = AppLocalizations.of(context).livePhoto;
        final badge = DecoratedBox(
          key: const Key('live-photo-badge'),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: iconOnly ? 5 : 7,
              vertical: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.motion_photos_on,
                  color: Colors.white,
                  size: 17,
                ),
                if (!iconOnly) ...[
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
        return Tooltip(message: label, child: badge);
      },
    );
  }
}
