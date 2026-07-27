import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../archives/archive_repository.dart';
import '../diary/diary_repository.dart';
import '../media/media_library.dart';
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
    if (!_configured) return const SyncState();
    void handleWriteGuard() {
      if (!_disposed && !_writeGuard.isEditing && _started) {
        unawaited(_autoSyncVisiblePeer());
      }
    }

    WidgetsBinding.instance.addObserver(this);
    _writeGuard.addListener(handleWriteGuard);
    ref.onDispose(() {
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
        unawaited(stop());
      } else if (previous?.isLocked == true) {
        unawaited(start());
      }
    });
    scheduleMicrotask(start);
    return const SyncState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
    if (_disposed || _started) return;
    if (ref.read(appLockControllerProvider).isLocked) return;
    _started = true;
    try {
      _pairedPeers = await _secureStore.loadPeerSecrets();
      state = state.copyWith(
        phase: SyncPhase.discovering,
        pairedDeviceIds: _pairedPeers.keys.toSet(),
        clearError: true,
      );
      _peerSubscription ??= _discovery.peers.listen(
        _handlePeers,
        onError: (Object error, StackTrace stackTrace) {
          _setFailure(error);
        },
      );
      await _discovery.start();
      _periodicTimer ??= Timer.periodic(const Duration(seconds: 45), (_) {
        if (_started && !state.isBusy) unawaited(_autoSyncVisiblePeer());
      });
    } on Object catch (error) {
      _started = false;
      _setFailure(error);
    }
  }

  Future<void> stop() async {
    if (!_started) return;
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
  }

  Future<void> pair(SyncPeer peer, String code) async {
    if (state.isBusy) return;
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
      _setFailure(error);
      rethrow;
    }
  }

  Future<void> syncNow([SyncPeer? requestedPeer]) async {
    if (state.isBusy || _writeGuard.isEditing) return;
    final peer = requestedPeer ?? _firstPairedVisiblePeer();
    if (peer == null) return;
    final secret = _pairedPeers[peer.deviceId];
    if (secret == null) return;
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
      if (result.conflicts == 0) {
        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(seconds: 3), () {
          if (!_disposed && _started && !state.isBusy) {
            state = state.copyWith(phase: SyncPhase.discovering);
          }
        });
      }
    } on Object catch (error) {
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
      return;
    }
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
