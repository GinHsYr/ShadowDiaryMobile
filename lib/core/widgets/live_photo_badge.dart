import 'dart:io';
import 'dart:ui' as ui;
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../l10n/app_localizations.dart';
import '../services/motion_photo_support.dart';

const _livePhotoCacheCapacity = 256;
final LinkedHashMap<String, Future<bool>> _livePhotoCache =
    LinkedHashMap<String, Future<bool>>();

Future<bool> isLivePhotoFile(File file, {File? motionFile}) async {
  final resolvedMotion = motionFile ?? _inferredMotionFile(file);
  final cacheKey = await _livePhotoCacheKey(file, resolvedMotion);
  final cached = _livePhotoCache.remove(cacheKey);
  if (cached != null) {
    _livePhotoCache[cacheKey] = cached;
    try {
      return await cached;
    } on Object {
      if (identical(_livePhotoCache[cacheKey], cached)) {
        _livePhotoCache.remove(cacheKey);
      }
      return false;
    }
  }

  final detection = () async {
    if (await resolvedMotion.exists()) return true;
    return _detectAnimatedImage(file);
  }();
  _livePhotoCache[cacheKey] = detection;
  while (_livePhotoCache.length > _livePhotoCacheCapacity) {
    _livePhotoCache.remove(_livePhotoCache.keys.first);
  }
  try {
    return await detection;
  } on Object {
    if (identical(_livePhotoCache[cacheKey], detection)) {
      _livePhotoCache.remove(cacheKey);
    }
    return false;
  }
}

Future<String> _livePhotoCacheKey(File image, File motion) async {
  final imageStamp = await _fileStamp(image);
  final motionStamp = await _fileStamp(motion);
  return '${image.path}|$imageStamp|${motion.path}|$motionStamp';
}

Future<String> _fileStamp(File file) async {
  try {
    final stat = await file.stat();
    return '${stat.type}|${stat.size}|${stat.modified.microsecondsSinceEpoch}';
  } on Object {
    return 'missing';
  }
}

File _inferredMotionFile(File file) {
  final stem = p.basenameWithoutExtension(file.path);
  return File(p.join(p.dirname(file.path), '$stem$motionPhotoFileSuffix'));
}

Future<bool> _detectAnimatedImage(File file) async {
  // Flutter 3.44 exposes ImmutableBuffer.fromUint8List (the file-backed
  // constructor is newer), so keep the bytes in the engine buffer rather than
  // passing them through a Dart image codec.
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    await file.readAsBytes(),
  );
  try {
    final codec = await ui.instantiateImageCodecFromBuffer(buffer);
    try {
      return codec.frameCount > 1;
    } finally {
      codec.dispose();
    }
  } finally {
    buffer.dispose();
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
