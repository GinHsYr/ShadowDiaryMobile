import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../archives/archive_repository.dart';
import '../diary/diary_repository.dart';
import '../media/media_library.dart';
import '../services/diary_image_debug_trace.dart';
import '../security/app_lock_controller.dart';
import 'lan_discovery_service.dart';
import 'sync_client.dart';
import 'sync_models.dart';
import 'sync_repository.dart';
import 'sync_secure_store.dart';
import 'sync_write_guard.dart';

final syncSecureStoreProvider = Provider<SyncSecureStore?>((ref) => null);

final syncRepositoryProvider = Provider<SyncRepository?>((ref) => null);

final syncDiscoveryServiceProvider = Provider<SyncDiscoveryService?>(
  (ref) => null,
);

final syncClientProvider = Provider<ShadowSyncClient?>((ref) => null);

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

final syncConflictsProvider = FutureProvider<List<SyncConflict>>((ref) {
  return ref.read(syncRepositoryProvider)?.listConflicts() ??
      Future.value(const <SyncConflict>[]);
});

class SyncController extends Notifier<SyncState> with WidgetsBindingObserver {
  StreamSubscription<List<SyncPeer>>? _peerSubscription;
  Timer? _periodicTimer;
  Timer? _retryTimer;
  Map<String, PairedPeerSecret> _pairedPeers = const {};
  final Map<String, DateTime> _lastAutoAttempt = {};
  bool _started = false;
  bool _disposed = false;

  bool get _configured =>
      ref.read(syncDiscoveryServiceProvider) != null &&
      ref.read(syncClientProvider) != null &&
      ref.read(syncSecureStoreProvider) != null &&
      ref.read(syncRepositoryProvider) != null;
  SyncDiscoveryService get _discovery =>
      ref.read(syncDiscoveryServiceProvider)!;
  ShadowSyncClient get _client => ref.read(syncClientProvider)!;
  SyncSecureStore get _secureStore => ref.read(syncSecureStoreProvider)!;
  SyncRepository get _repository => ref.read(syncRepositoryProvider)!;
  SyncWriteGuard get _writeGuard => ref.read(syncWriteGuardProvider);

  @override
  SyncState build() {
    if (!_configured) {
      DiaryImageDebugTrace.event('sync.controller.unconfigured');
      return const SyncState();
    }
    void handleWriteGuard() {
      if (!_disposed && !_writeGuard.isEditing && _started) {
        unawaited(_autoSyncVisiblePeer());
      }
    }

    WidgetsBinding.instance.addObserver(this);
    _writeGuard.addListener(handleWriteGuard);
    ref.onDispose(() {
      DiaryImageDebugTrace.event('sync.controller.dispose');
      _disposed = true;
      WidgetsBinding.instance.removeObserver(this);
      _writeGuard.removeListener(handleWriteGuard);
      _periodicTimer?.cancel();
      _retryTimer?.cancel();
      unawaited(_peerSubscription?.cancel());
      unawaited(_discovery.stop());
    });
    ref.listen(appLockControllerProvider, (previous, next) {
      if (next.isLocked) {
        DiaryImageDebugTrace.event('sync.controller.locked');
        unawaited(stop());
      } else if (previous?.isLocked == true) {
        DiaryImageDebugTrace.event('sync.controller.unlocked');
        unawaited(start());
      }
    });
    scheduleMicrotask(start);
    return const SyncState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    DiaryImageDebugTrace.event('sync.lifecycle', {
      'state': state.name,
      'started': _started,
    });
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(start());
      case AppLifecycleState.inactive ||
          AppLifecycleState.paused ||
          AppLifecycleState.detached ||
          AppLifecycleState.hidden:
        unawaited(stop());
    }
  }

  Future<void> start() async {
    if (_disposed || _started) {
      DiaryImageDebugTrace.event('sync.controller.start.skipped', {
        'disposed': _disposed,
        'started': _started,
      });
      return;
    }
    if (ref.read(appLockControllerProvider).isLocked) {
      DiaryImageDebugTrace.event('sync.controller.start.skipped', {
        'reason': 'app-locked',
      });
      return;
    }
    _started = true;
    DiaryImageDebugTrace.event('sync.controller.start.begin');
    try {
      _pairedPeers = await _secureStore.loadPeerSecrets();
      DiaryImageDebugTrace.event('sync.controller.peers.loaded', {
        'pairedCount': _pairedPeers.length,
        'pairedIds': _pairedPeers.keys.join(','),
      });
      state = state.copyWith(
        phase: SyncPhase.discovering,
        pairedDeviceIds: _pairedPeers.keys.toSet(),
        clearError: true,
      );
      _peerSubscription ??= _discovery.peers.listen(
        _handlePeers,
        onError: (Object error, StackTrace stackTrace) {
          DiaryImageDebugTrace.error('sync.controller.discovery.failed', error);
          _setFailure(error);
        },
      );
      await _discovery.start();
      DiaryImageDebugTrace.event('sync.controller.start.complete');
      _periodicTimer ??= Timer.periodic(const Duration(seconds: 45), (_) {
        if (_started && !state.isBusy) unawaited(_autoSyncVisiblePeer());
      });
    } on Object catch (error) {
      _started = false;
      DiaryImageDebugTrace.error('sync.controller.start.failed', error);
      _setFailure(error);
    }
  }

  Future<void> stop() async {
    if (!_started) {
      DiaryImageDebugTrace.event('sync.controller.stop.skipped', {
        'reason': 'not-started',
      });
      return;
    }
    DiaryImageDebugTrace.event('sync.controller.stop.begin');
    _started = false;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _discovery.stop();
    if (!_disposed) {
      state = state.copyWith(
        phase: SyncPhase.disabled,
        peers: const [],
        clearActivePeer: true,
      );
    }
    DiaryImageDebugTrace.event('sync.controller.stop.complete');
  }

  Future<void> pair(SyncPeer peer, String code) async {
    if (state.isBusy) {
      DiaryImageDebugTrace.event('pair.skipped', {'reason': 'busy'});
      return;
    }
    DiaryImageDebugTrace.event('pair.requested', {'peer': peer.deviceId});
    state = state.copyWith(
      phase: SyncPhase.pairing,
      activePeerId: peer.deviceId,
      clearError: true,
    );
    try {
      final secret = await _client.pair(peer, code);
      _pairedPeers = {..._pairedPeers, secret.deviceId: secret};
      state = state.copyWith(
        pairedDeviceIds: _pairedPeers.keys.toSet(),
        phase: SyncPhase.discovering,
      );
      await syncNow(peer);
    } on Object catch (error) {
      DiaryImageDebugTrace.error('pair.controller.failed', error, {
        'peer': peer.deviceId,
      });
      _setFailure(error);
      rethrow;
    }
  }

  Future<void> syncNow([SyncPeer? requestedPeer]) async {
    if (state.isBusy || _writeGuard.isEditing) {
      DiaryImageDebugTrace.event('sync.request.skipped', {
        'busy': state.isBusy,
        'editing': _writeGuard.isEditing,
      });
      return;
    }
    final peer = requestedPeer ?? _firstPairedVisiblePeer();
    if (peer == null) {
      DiaryImageDebugTrace.event('sync.request.skipped', {
        'reason': 'no-paired-visible-peer',
        'visiblePeers': state.peers.map((item) => item.deviceId).join(','),
      });
      return;
    }
    final secret = _pairedPeers[peer.deviceId];
    if (secret == null) {
      DiaryImageDebugTrace.event('sync.request.skipped', {
        'reason': 'missing-paired-secret',
        'peer': peer.deviceId,
      });
      return;
    }
    DiaryImageDebugTrace.event('sync.request.accepted', {
      'peer': peer.deviceId,
      'manual': requestedPeer != null,
    });
    _lastAutoAttempt[peer.deviceId] = DateTime.now();
    state = state.copyWith(
      phase: SyncPhase.connecting,
      activePeerId: peer.deviceId,
      progress: const SyncProgress(),
      clearError: true,
    );
    try {
      state = state.copyWith(phase: SyncPhase.syncing);
      final result = await _client.synchronize(
        peer,
        secret,
        onProgress: (progress) {
          if (!_disposed) state = state.copyWith(progress: progress);
        },
      );
      _invalidateContent();
      final totalConflicts = (await _repository.listConflicts()).length;
      state = state.copyWith(
        phase: totalConflicts > 0 ? SyncPhase.conflicts : SyncPhase.completed,
        conflictCount: totalConflicts,
        lastSyncAt: DateTime.now(),
        clearActivePeer: true,
        clearError: true,
      );
      ref.invalidate(syncConflictsProvider);
      DiaryImageDebugTrace.event('sync.controller.complete', {
        'peer': peer.deviceId,
        'appliedRecords': result.appliedRecords,
        'conflicts': totalConflicts,
        'transferredBytes': result.transferredBytes,
      });
      if (result.conflicts == 0) {
        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(seconds: 3), () {
          if (!_disposed && _started && !state.isBusy) {
            state = state.copyWith(phase: SyncPhase.discovering);
          }
        });
      }
    } on Object catch (error) {
      DiaryImageDebugTrace.error('sync.controller.failed', error, {
        'peer': peer.deviceId,
      });
      _setFailure(error);
    }
  }

  Future<void> unpair(String deviceId) async {
    await _secureStore.deletePeerSecret(deviceId);
    await _repository.forgetPeer(deviceId);
    _pairedPeers = {..._pairedPeers}..remove(deviceId);
    state = state.copyWith(
      pairedDeviceIds: _pairedPeers.keys.toSet(),
      conflictCount: (await _repository.listConflicts()).length,
    );
    ref.invalidate(syncConflictsProvider);
  }

  Future<void> resolveConflict(
    SyncConflict conflict,
    SyncConflictChoice choice,
  ) async {
    await _repository.resolveConflict(conflict, choice);
    _invalidateContent();
    final remaining = (await _repository.listConflicts()).length;
    state = state.copyWith(
      conflictCount: remaining,
      phase: remaining == 0 ? SyncPhase.discovering : SyncPhase.conflicts,
    );
    ref.invalidate(syncConflictsProvider);
  }

  void _handlePeers(List<SyncPeer> peers) {
    if (_disposed) return;
    DiaryImageDebugTrace.event('sync.controller.peers.visible', {
      'count': peers.length,
      'peerIds': peers.map((peer) => peer.deviceId).join(','),
      'pairedVisible': peers
          .where((peer) => _pairedPeers.containsKey(peer.deviceId))
          .map((peer) => peer.deviceId)
          .join(','),
    });
    state = state.copyWith(peers: peers);
    unawaited(_autoSyncVisiblePeer());
  }

  Future<void> _autoSyncVisiblePeer() async {
    if (!_started || state.isBusy || _writeGuard.isEditing) return;
    final peer = _firstPairedVisiblePeer();
    if (peer == null) return;
    final lastAttempt = _lastAutoAttempt[peer.deviceId];
    if (lastAttempt != null &&
        DateTime.now().difference(lastAttempt) < const Duration(seconds: 30)) {
      DiaryImageDebugTrace.event('sync.auto.skipped', {
        'peer': peer.deviceId,
        'reason': 'retry-cooldown',
      });
      return;
    }
    DiaryImageDebugTrace.event('sync.auto.starting', {'peer': peer.deviceId});
    await syncNow(peer);
  }

  SyncPeer? _firstPairedVisiblePeer() {
    for (final peer in state.peers) {
      if (_pairedPeers.containsKey(peer.deviceId)) return peer;
    }
    return null;
  }

  void _setFailure(Object error) {
    if (_disposed) return;
    DiaryImageDebugTrace.error('sync.controller.state.failed', error);
    state = state.copyWith(
      phase: SyncPhase.failed,
      error: _friendlyError(error),
      clearActivePeer: true,
    );
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 8), () {
      if (!_disposed && _started && !state.isBusy) {
        state = state.copyWith(phase: SyncPhase.discovering);
        unawaited(_autoSyncVisiblePeer());
      }
    });
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('authentication')) return 'authentication_failed';
    if (text.contains('Pairing code')) return 'invalid_pairing_code';
    if (text.contains('Timeout')) return 'connection_timeout';
    if (text.contains('hash mismatch')) return 'asset_hash_mismatch';
    return 'connection_failed';
  }

  void _invalidateContent() {
    ref
      ..invalidate(diaryOverviewProvider)
      ..invalidate(diaryEntryListProvider)
      ..invalidate(archiveListProvider)
      ..invalidate(mediaLibraryProvider);
  }
}
