import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final syncWriteGuardProvider = Provider<SyncWriteGuard>(
  (ref) => SyncWriteGuard(),
);

class SyncWriteGuard {
  int _editingSessions = 0;
  final Set<VoidCallback> _listeners = {};

  bool get isEditing => _editingSessions > 0;

  void beginEditing() {
    _editingSessions++;
    if (_editingSessions == 1) _notifyListeners();
  }

  void endEditing() {
    assert(
      _editingSessions > 0,
      'Every editing session must be ended exactly once.',
    );
    if (_editingSessions == 0) return;
    _editingSessions--;
    if (_editingSessions == 0) _notifyListeners();
  }

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }
}
