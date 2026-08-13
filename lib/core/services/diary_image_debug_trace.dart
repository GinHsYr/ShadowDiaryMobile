import 'dart:io';

import 'package:flutter/foundation.dart';

/// Emits concise, debug-only diagnostics for the image synchronization path.
class DiaryImageDebugTrace {
  DiaryImageDebugTrace._();

  static const prefix = 'SD_IMAGE_SYNC';
  static final String _run = DateTime.now().millisecondsSinceEpoch
      .toRadixString(36);
  static final Set<String> _reportedResolutions = <String>{};
  static final Set<String> _reportedOnce = <String>{};
  static String _session = 'idle';
  static int _sessionSequence = 0;

  static bool get enabled => kDebugMode;

  static void appReady({String? imageDirectory}) {
    event('trace.ready', {
      'mode': kDebugMode ? 'debug' : 'non-debug',
      'imageDirectory': imageDirectory,
    });
  }

  static void beginSync({required String peerId, required int endpointCount}) {
    if (!kDebugMode) return;
    _beginSession();
    _reportedResolutions.clear();
    event('sync.begin', {'peer': peerId, 'endpoints': endpointCount});
  }

  static void beginPair({required String peerId, required int endpointCount}) {
    if (!kDebugMode) return;
    _beginSession();
    event('pair.begin', {'peer': peerId, 'endpoints': endpointCount});
  }

  static void once(
    String key,
    String step, [
    Map<String, Object?> fields = const {},
  ]) {
    if (!kDebugMode || !_reportedOnce.add(key)) return;
    event(step, fields);
  }

  static void event(String step, [Map<String, Object?> fields = const {}]) {
    if (!kDebugMode) return;
    final values = <String, Object?>{
      'run': _run,
      'session': _session,
      ...fields,
    };
    final details = values.entries
        .map((entry) => '${entry.key}="${_format(entry.value)}"')
        .join(' ');
    debugPrint('[$prefix] $step${details.isEmpty ? '' : ' $details'}');
  }

  static void error(
    String step,
    Object error, [
    Map<String, Object?> fields = const {},
  ]) {
    event(step, {...fields, 'errorType': error.runtimeType, 'error': error});
  }

  static String hashPrefix(String value) {
    const length = 12;
    return value.length <= length ? value : value.substring(0, length);
  }

  static void _beginSession() {
    _session =
        '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-${++_sessionSequence}';
  }

  static Map<String, Object?> fileFields(File file) {
    return _readFileState(file);
  }

  static void fileState(
    String step, {
    required String assetId,
    required File? file,
    Map<String, Object?> fields = const {},
  }) {
    if (!kDebugMode) return;
    event(step, {'asset': assetId, ..._readFileState(file), ...fields});
  }

  static void imageResolution({
    required String source,
    required File? file,
    required String surface,
  }) {
    if (!kDebugMode) return;
    final state = _readFileState(file);
    final key =
        '$surface|$source|${state['path']}|${state['exists']}|${state['bytes']}';
    if (!_reportedResolutions.add(key)) return;
    event('image.resolve', {'surface': surface, 'source': source, ...state});
  }

  static Map<String, Object?> _readFileState(File? file) {
    if (file == null) {
      return const {'path': null, 'exists': false, 'bytes': null};
    }
    try {
      final exists = file.existsSync();
      return {
        'path': file.path,
        'exists': exists,
        'bytes': exists ? file.lengthSync() : null,
      };
    } on Object catch (error) {
      return {
        'path': file.path,
        'exists': 'error',
        'bytes': null,
        'fileError': error,
      };
    }
  }

  static String _format(Object? value) {
    var text = value?.toString() ?? 'null';
    text = text.replaceAll(RegExp(r'\s+'), ' ').replaceAll('"', r'\"');
    const maxLength = 240;
    return text.length <= maxLength
        ? text
        : '${text.substring(0, maxLength)}...';
  }
}
