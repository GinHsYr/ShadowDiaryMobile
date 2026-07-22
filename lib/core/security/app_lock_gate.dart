import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'app_lock_controller.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _authenticateOnResume = false;
  bool _authenticationOwnsLifecycle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _unlockIfNeeded();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    final lockState = ref.read(appLockControllerProvider);
    if (lifecycleState == AppLifecycleState.resumed) {
      if (_authenticationOwnsLifecycle) {
        _authenticationOwnsLifecycle = false;
        return;
      }
      if (_authenticateOnResume) {
        _authenticateOnResume = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _unlockIfNeeded();
        });
        WidgetsBinding.instance.scheduleFrame();
      }
      return;
    }

    if (lockState.isAuthenticating) {
      _authenticationOwnsLifecycle = true;
      return;
    }

    if (lockState.enabled) {
      _authenticationOwnsLifecycle = false;
      _authenticateOnResume = true;
      ref.read(appLockControllerProvider.notifier).lock();
    }
  }

  Future<void> _unlockIfNeeded() async {
    if (!mounted) {
      return;
    }
    final lockState = ref.read(appLockControllerProvider);
    if (!lockState.enabled ||
        !lockState.isLocked ||
        lockState.isAuthenticating) {
      return;
    }

    await ref
        .read(appLockControllerProvider.notifier)
        .unlock(AppLocalizations.of(context).appLockAuthenticateReason);
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockControllerProvider);
    final locked = lockState.enabled && lockState.isLocked;

    return Stack(
      fit: StackFit.expand,
      children: [
        TickerMode(
          enabled: !locked,
          child: Offstage(offstage: locked, child: widget.child),
        ),
        if (locked)
          Positioned.fill(
            child: _LockedScreen(state: lockState, onUnlock: _unlockIfNeeded),
          ),
      ],
    );
  }
}

class _LockedScreen extends StatelessWidget {
  const _LockedScreen({required this.state, required this.onUnlock});

  final AppLockState state;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final errorMessage = switch (state.lastResult) {
      AppLockResult.unavailable => l10n.appLockUnavailable,
      AppLockResult.canceled => l10n.appLockCanceled,
      AppLockResult.failed => l10n.appLockFailed,
      _ => null,
    };

    return ColoredBox(
      key: const Key('app-lock-screen'),
      color: colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 42,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    l10n.appLockLockedTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.appLockLockedDescription,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      errorMessage,
                      key: const Key('app-lock-error'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    key: const Key('app-lock-unlock-button'),
                    onPressed: state.isAuthenticating ? null : onUnlock,
                    icon: state.isAuthenticating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_open_rounded),
                    label: Text(
                      state.isAuthenticating
                          ? l10n.appLockAuthenticating
                          : l10n.appLockUnlock,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
