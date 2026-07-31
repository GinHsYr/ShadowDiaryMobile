import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/app/app.dart';
import 'package:shadow_diary_mobile/core/diary/diary_entry.dart';
import 'package:shadow_diary_mobile/core/diary/diary_overview.dart';
import 'package:shadow_diary_mobile/core/diary/diary_repository.dart';
import 'package:shadow_diary_mobile/core/security/app_lock_controller.dart';
import 'package:shadow_diary_mobile/core/security/app_lock_gate.dart';
import 'package:shadow_diary_mobile/core/services/service_contracts.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings_controller.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings_repository.dart';

void main() {
  testWidgets(
    'enables and disables system unlock only after successful authentication',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = MemorySettingsRepository(
        const AppSettings(localePreference: AppLocalePreference.en),
      );
      final authentication = FakeDeviceAuthenticationService(
        results: [
          DeviceAuthenticationResult.success,
          DeviceAuthenticationResult.canceled,
          DeviceAuthenticationResult.success,
        ],
      );
      await tester.pumpWidget(_testApp(repository, authentication));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('System unlock'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('app-lock-toggle')));
      await tester.pumpAndSettle();

      expect(authentication.reasons, [
        'Authenticate to turn on system unlock for ShadowDiary',
      ]);
      expect(repository.settings.appLockEnabled, isTrue);
      expect(repository.settings.appLockDelay, AppLockDelay.oneMinute);
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('app-lock-toggle')))
            .value,
        isTrue,
      );
      expect(find.byKey(const Key('app-lock-screen')), findsNothing);
      expect(
        find.text('Require authentication after 1 minute away from the app'),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('app-lock-delay-selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('app-lock-delay-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5 minutes'));
      await tester.pumpAndSettle();

      expect(repository.settings.appLockDelay, AppLockDelay.fiveMinutes);
      expect(
        find.text('Require authentication after 5 minutes away from the app'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.byKey(const Key('app-lock-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('app-lock-toggle')));
      await tester.pumpAndSettle();

      expect(repository.settings.appLockEnabled, isTrue);
      expect(authentication.reasons, [
        'Authenticate to turn on system unlock for ShadowDiary',
        'Authenticate to turn off system unlock for ShadowDiary',
      ]);
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('app-lock-toggle')))
            .value,
        isTrue,
      );
      expect(find.text('Authentication was not completed.'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('app-lock-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('app-lock-toggle')));
      await tester.pumpAndSettle();

      expect(repository.settings.appLockEnabled, isFalse);
      expect(authentication.reasons, [
        'Authenticate to turn on system unlock for ShadowDiary',
        'Authenticate to turn off system unlock for ShadowDiary',
        'Authenticate to turn off system unlock for ShadowDiary',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('does not enable app lock when system unlock is unavailable', (
    tester,
  ) async {
    final repository = MemorySettingsRepository(
      const AppSettings(localePreference: AppLocalePreference.en),
    );
    final authentication = FakeDeviceAuthenticationService(available: false);
    await tester.pumpWidget(_testApp(repository, authentication));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-lock-toggle')));
    await tester.pumpAndSettle();

    expect(repository.settings.appLockEnabled, isFalse);
    expect(authentication.reasons, isEmpty);
    expect(
      find.text(
        'Set up biometrics, a PIN, pattern, or password in system settings first.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('locks at launch and only after the configured time away', (
    tester,
  ) async {
    final clock = MutableClock(DateTime(2026, 7, 28, 12));
    final repository = MemorySettingsRepository(
      const AppSettings(
        localePreference: AppLocalePreference.en,
        appLockEnabled: true,
        appLockDelay: AppLockDelay.fiveMinutes,
      ),
    );
    final authentication = FakeDeviceAuthenticationService(
      results: [
        DeviceAuthenticationResult.canceled,
        DeviceAuthenticationResult.success,
        DeviceAuthenticationResult.success,
      ],
    );
    await tester.pumpWidget(
      _testApp(repository, authentication, now: clock.now),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-lock-screen')), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(find.text('Authentication was not completed.'), findsOneWidget);
    expect(authentication.reasons, ['Unlock ShadowDiary to view your diaries']);

    await tester.tap(find.byKey(const Key('app-lock-unlock-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-lock-screen')), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(authentication.reasons, hasLength(2));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ShadowDiaryApp)),
    );
    expect(container.read(appLockControllerProvider).enabled, isTrue);
    expect(container.read(appLockControllerProvider).isAuthenticating, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();

    clock.advance(const Duration(minutes: 10));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(authentication.reasons, hasLength(2));
    expect(container.read(appLockControllerProvider).isLocked, isFalse);
    expect(find.byKey(const Key('app-lock-screen')), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    expect(container.read(appLockControllerProvider).isLocked, isFalse);
    clock.advance(const Duration(minutes: 4, seconds: 59));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(authentication.reasons, hasLength(2));
    expect(container.read(appLockControllerProvider).isLocked, isFalse);
    expect(find.byKey(const Key('app-lock-screen')), findsNothing);
    expect(find.text('Home'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    clock.advance(const Duration(minutes: 5));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(authentication.reasons, hasLength(3));
    expect(container.read(appLockControllerProvider).isLocked, isFalse);
    expect(find.byKey(const Key('app-lock-screen')), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });
}

Widget _testApp(
  MemorySettingsRepository repository,
  DeviceAuthenticationService authentication, {
  DateTime Function()? now,
}) {
  return ProviderScope(
    overrides: [
      appSettingsRepositoryProvider.overrideWithValue(repository),
      initialAppSettingsProvider.overrideWithValue(repository.settings),
      deviceAuthenticationServiceProvider.overrideWithValue(authentication),
      if (now != null) appLockNowProvider.overrideWithValue(now),
      diaryRepositoryProvider.overrideWithValue(EmptyDiaryRepository()),
    ],
    child: const ShadowDiaryApp(),
  );
}

class MutableClock {
  MutableClock(this._value);

  DateTime _value;

  DateTime now() => _value;

  void advance(Duration duration) {
    _value = _value.add(duration);
  }
}

class FakeDeviceAuthenticationService implements DeviceAuthenticationService {
  FakeDeviceAuthenticationService({
    this.available = true,
    Iterable<DeviceAuthenticationResult> results = const [],
  }) : _results = Queue.of(results);

  final bool available;
  final Queue<DeviceAuthenticationResult> _results;
  final List<String> reasons = [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<DeviceAuthenticationResult> authenticate(
    String localizedReason,
  ) async {
    reasons.add(localizedReason);
    return _results.isEmpty
        ? DeviceAuthenticationResult.failed
        : _results.removeFirst();
  }
}

class MemorySettingsRepository implements AppSettingsRepository {
  MemorySettingsRepository(this.settings);

  AppSettings settings;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async {
    this.settings = settings;
  }
}

class EmptyDiaryRepository implements DiaryRepository {
  @override
  Future<List<DiaryEntry>> listEntries() async => const [];

  @override
  Future<DiaryEntry?> findByDate(DateTime date) async => null;

  @override
  Future<DiaryEntry?> findById(String id) async => null;

  @override
  Future<DiaryOverview> loadOverview() async => DiaryOverview.empty;

  @override
  Future<void> save(DiaryEntry entry) async {}
}
