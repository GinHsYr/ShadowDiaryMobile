import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/sync/sync_controller.dart';
import 'package:shadow_diary_mobile/core/sync/sync_models.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings.dart';
import 'package:shadow_diary_mobile/core/theme/app_theme.dart';
import 'package:shadow_diary_mobile/features/settings/lan_sync_page.dart';
import 'package:shadow_diary_mobile/l10n/app_localizations.dart';

void main() {
  testWidgets('shows paired devices without narrow-screen overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncControllerProvider.overrideWith(_PreviewSyncController.new),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          theme: AppTheme.light(ThemeSeed.teal),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MediaQuery(
            data: MediaQueryData(size: Size(320, 640), disableAnimations: true),
            child: LanSyncPage(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('sync-hero-card')), findsOneWidget);
    expect(find.text('局域网同步'), findsOneWidget);
    expect(find.text('Studio Desktop'), findsOneWidget);
    expect(find.text('已配对'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the empty discovery state in dark mode', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: _SyncTestApp(themeMode: ThemeMode.dark)),
    );
    await tester.pump();

    expect(find.text('No desktop app found'), findsOneWidget);
    expect(find.byKey(const Key('sync-now-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('waits for the code dialog to close before pairing', (
    tester,
  ) async {
    _PairingSyncController.reset();
    addTearDown(_PairingSyncController.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncControllerProvider.overrideWith(_PairingSyncController.new),
        ],
        child: const _SyncTestApp(themeMode: ThemeMode.light),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Pair'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(
      find.byKey(const Key('sync-pair-code-field')),
      '123456',
    );
    await tester.tap(find.byKey(const Key('sync-pair-confirm')));
    await tester.pump();

    expect(_PairingSyncController.pairCalls, 0);
    expect(find.byKey(const Key('sync-pair-code-dialog')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    expect(_PairingSyncController.pairCalls, 0);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(_PairingSyncController.pairCalls, 1);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Paired'), findsOneWidget);
    expect(find.byKey(const Key('sync-pair-code-dialog')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a git-style diff and confirms before resolving', (
    tester,
  ) async {
    _ConflictSyncController.reset();
    addTearDown(_ConflictSyncController.reset);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncControllerProvider.overrideWith(_ConflictSyncController.new),
          syncConflictsProvider.overrideWith((ref) async => [_testConflict]),
        ],
        child: const _SyncTestApp(themeMode: ThemeMode.light),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Phone title'), 160);
    await tester.tap(find.text('Phone title'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('sync-conflict-diff')), findsOneWidget);
    expect(find.text('--- This phone'), findsOneWidget);
    expect(find.text('+++ Desktop'), findsOneWidget);
    expect(find.text('Title: Phone title'), findsOneWidget);
    expect(find.text('Title: Desktop title'), findsOneWidget);
    expect(find.byKey(const Key('sync-diff-removed')), findsWidgets);
    expect(find.byKey(const Key('sync-diff-added')), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('sync-conflict-keep-remote')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const Key('sync-conflict-confirm-dialog')),
      findsOneWidget,
    );
    expect(find.text('Save this conflict resolution?'), findsOneWidget);
    expect(_ConflictSyncController.resolveCalls, 0);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const Key('sync-conflict-diff')), findsOneWidget);
    expect(_ConflictSyncController.resolveCalls, 0);

    await tester.tap(find.byKey(const Key('sync-conflict-keep-remote')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const Key('sync-conflict-confirm-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(_ConflictSyncController.resolveCalls, 1);
    expect(_ConflictSyncController.lastChoice, SyncConflictChoice.keepRemote);
    expect(find.byKey(const Key('sync-conflict-confirm-dialog')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the cause of an existing timestamp-only conflict', (
    tester,
  ) async {
    _ConflictSyncController.reset();
    addTearDown(_ConflictSyncController.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncControllerProvider.overrideWith(_ConflictSyncController.new),
          syncConflictsProvider.overrideWith(
            (ref) async => [_timestampOnlyConflict],
          ),
        ],
        child: const _SyncTestApp(themeMode: ThemeMode.light),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Same title'), 160);
    await tester.tap(find.text('Same title'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Updated at:'), findsNWidgets(2));
    expect(find.byKey(const Key('sync-diff-removed')), findsOneWidget);
    expect(find.byKey(const Key('sync-diff-added')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final _testConflict = SyncConflict(
  id: 'conflict-1',
  entityType: SyncEntityType.diary,
  entityId: 'diary-1',
  peerDeviceId: 'desktop-1',
  localPayload: const {
    'id': 'diary-1',
    'title': 'Phone title',
    'content': '<p>Shared line</p><p>Phone-only line</p>',
    'plainContent': 'Shared line\nPhone-only line',
    'mood': 'calm',
    'weather': 'sunny',
    'calendarDate': '2026-07-26',
    'tags': <String>['phone'],
  },
  remotePayload: const {
    'id': 'diary-1',
    'title': 'Desktop title',
    'content': '<p>Shared line</p><p>Desktop-only line</p>',
    'plainContent': 'Shared line\nDesktop-only line',
    'mood': 'happy',
    'weather': 'rainy',
    'calendarDate': '2026-07-26',
    'tags': <String>['desktop'],
  },
  localVector: const {'phone-1': 2},
  remoteVector: const {'desktop-1': 2},
  createdAt: DateTime(2026, 7, 26, 12),
);

final _timestampOnlyConflict = SyncConflict(
  id: 'conflict-timestamp',
  entityType: SyncEntityType.diary,
  entityId: 'diary-timestamp',
  peerDeviceId: 'desktop-1',
  localPayload: const {
    'id': 'diary-timestamp',
    'title': 'Same title',
    'content': '<p>Same body</p>',
    'plainContent': 'Same body',
    'mood': 'calm',
    'weather': null,
    'calendarDate': '2026-07-19',
    'tags': <String>[],
    'createdAt': 1784390400000,
    'updatedAt': 1784721570267,
  },
  remotePayload: const {
    'id': 'diary-timestamp',
    'title': 'Same title',
    'content': '<p>Same body</p>',
    'plainContent': 'Same body',
    'mood': 'calm',
    'weather': null,
    'calendarDate': '2026-07-19',
    'tags': <String>[],
    'createdAt': 1784390400000,
    'updatedAt': 1784625068382,
  },
  localVector: const {'phone-1': 2},
  remoteVector: const {'desktop-1': 2},
  createdAt: DateTime(2026, 7, 27),
);

class _PreviewSyncController extends SyncController {
  @override
  SyncState build() {
    return const SyncState(
      phase: SyncPhase.discovering,
      pairedDeviceIds: {'desktop-1'},
      peers: [
        SyncPeer(
          deviceId: 'desktop-1',
          name: 'Studio Desktop',
          host: '192.168.1.8',
          port: 45454,
          pairingAvailable: false,
        ),
      ],
    );
  }
}

class _PairingSyncController extends SyncController {
  static int pairCalls = 0;

  static const _peer = SyncPeer(
    deviceId: 'desktop-1',
    name: 'Studio Desktop',
    host: '192.168.1.8',
    port: 45454,
    pairingAvailable: true,
  );

  static void reset() {
    pairCalls = 0;
  }

  @override
  SyncState build() {
    return const SyncState(phase: SyncPhase.discovering, peers: [_peer]);
  }

  @override
  Future<void> pair(SyncPeer peer, String code) async {
    pairCalls++;
    state = state.copyWith(
      phase: SyncPhase.pairing,
      activePeerId: peer.deviceId,
    );
    await Future<void>.delayed(Duration.zero);
    state = state.copyWith(
      phase: SyncPhase.connecting,
      pairedDeviceIds: {peer.deviceId},
    );
    await Future<void>.delayed(Duration.zero);
    state = state.copyWith(phase: SyncPhase.completed, clearActivePeer: true);
  }
}

class _ConflictSyncController extends SyncController {
  static int resolveCalls = 0;
  static SyncConflictChoice? lastChoice;

  static void reset() {
    resolveCalls = 0;
    lastChoice = null;
  }

  @override
  SyncState build() {
    return const SyncState(
      phase: SyncPhase.conflicts,
      conflictCount: 1,
      pairedDeviceIds: {'desktop-1'},
    );
  }

  @override
  Future<void> resolveConflict(
    SyncConflict conflict,
    SyncConflictChoice choice,
  ) async {
    resolveCalls++;
    lastChoice = choice;
    state = state.copyWith(phase: SyncPhase.discovering, conflictCount: 0);
  }
}

class _SyncTestApp extends StatelessWidget {
  const _SyncTestApp({required this.themeMode});

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('en'),
      themeMode: themeMode,
      theme: AppTheme.light(ThemeSeed.neutral),
      darkTheme: AppTheme.dark(ThemeSeed.neutral),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MediaQuery(
        data: MediaQueryData(size: Size(400, 800), disableAnimations: true),
        child: LanSyncPage(),
      ),
    );
  }
}
