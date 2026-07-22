import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadow_diary_mobile/app/app.dart';
import 'package:shadow_diary_mobile/app/app_ionicons.dart';
import 'package:shadow_diary_mobile/app/router.dart';
import 'package:shadow_diary_mobile/app/shell.dart';
import 'package:shadow_diary_mobile/core/archives/archive.dart';
import 'package:shadow_diary_mobile/core/archives/archive_repository.dart';
import 'package:shadow_diary_mobile/core/backup/backup_import_service.dart';
import 'package:shadow_diary_mobile/core/diary/diary_entry.dart';
import 'package:shadow_diary_mobile/core/diary/diary_overview.dart';
import 'package:shadow_diary_mobile/core/diary/diary_repository.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings_controller.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings_repository.dart';
import 'package:shadow_diary_mobile/core/widgets/app_page.dart';

void main() {
  testWidgets('navigates across the shell without top or floating bars', (
    tester,
  ) async {
    final repository = MemorySettingsRepository(
      const AppSettings(localePreference: AppLocalePreference.zh),
    );
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.textContaining('你好，准备写点什么？'), findsOneWidget);
    expect(find.byKey(const Key('home-calendar-card')), findsOneWidget);
    expect(find.byKey(const Key('home-statistics-cards')), findsOneWidget);
    expect(find.text('从今天开始记录'), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(SliverAppBar), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('首页'), findsOneWidget);
    expect(find.byIcon(AppIonicons.bookOutline), findsOneWidget);
    expect(find.byIcon(AppIonicons.folderOpenOutline), findsOneWidget);
    expect(find.byIcon(AppIonicons.imagesOutline), findsOneWidget);
    expect(find.byIcon(AppIonicons.settingsOutline), findsOneWidget);

    await tester.tap(find.text('档案'));
    await tester.pumpAndSettle();
    expect(find.text('还没有档案'), findsOneWidget);

    GoRouter.of(
      tester.element(find.text('还没有档案')),
    ).go(AppRoutes.editEntry('entry-1'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('editor-exit-button')), findsOneWidget);
    expect(find.byKey(const Key('editor-day-picker')), findsOneWidget);
    expect(find.byKey(const Key('editor-quill-editor')), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('opens the editor for a tapped home calendar date', (
    tester,
  ) async {
    final settingsRepository = MemorySettingsRepository(
      const AppSettings(localePreference: AppLocalePreference.en),
    );
    final diaryRepository = RecordingDiaryRepository();
    await tester.pumpWidget(
      _testApp(settingsRepository, diaryRepository: diaryRepository),
    );
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final selectedDate = DateTime(now.year, now.month, 15);
    final calendarDay = find.descendant(
      of: find.byKey(const Key('home-month-calendar')),
      matching: find.text('15'),
    );

    expect(calendarDay, findsOneWidget);
    await tester.tap(calendarDay);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('editor-quill-editor')), findsOneWidget);
    expect(diaryRepository.requestedDates, <DateTime>[selectedDate]);
  });

  testWidgets('creates an archive through the configured archive routes', (
    tester,
  ) async {
    final settingsRepository = MemorySettingsRepository(
      const AppSettings(localePreference: AppLocalePreference.en),
    );
    final archiveRepository = RecordingArchiveRepository();
    await tester.pumpWidget(
      _testApp(settingsRepository, archiveRepository: archiveRepository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Archives'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('archives-add-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('archive-editor-form')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('archive-name-field')),
      'Alice',
    );
    await tester.tap(find.byKey(const Key('archive-save-button')));
    await tester.pumpAndSettle();

    expect(archiveRepository.archives, hasLength(1));
    expect(find.byKey(const Key('archive-editor-form')), findsNothing);
    expect(find.text('Alice'), findsOneWidget);
    expect(
      find.byKey(Key('archive-card-${archiveRepository.archives.single.id}')),
      findsOneWidget,
    );
  });

  testWidgets('changes and persists theme and locale preferences', (
    tester,
  ) async {
    final repository = MemorySettingsRepository(
      const AppSettings(localePreference: AppLocalePreference.zh),
    );
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuButton<AppThemeMode>), findsOneWidget);
    expect(find.byType(PopupMenuButton<AppLocalePreference>), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(
      tester
          .widget<PopupMenuButton<AppThemeMode>>(
            find.byType(PopupMenuButton<AppThemeMode>),
          )
          .color,
      const Color(0xFFE7E7E7),
    );
    expect(
      Theme.of(
        tester.element(find.byKey(const Key('theme-mode-selector'))),
      ).colorScheme.surfaceContainerHighest,
      const Color(0xFFDCDCDC),
    );
    expect(
      tester.getCenter(find.text('显示模式')).dx,
      lessThan(
        tester.getCenter(find.byKey(const Key('theme-mode-selector'))).dx,
      ),
    );

    await tester.tap(find.byType(PopupMenuButton<AppThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色').last);
    await tester.pumpAndSettle();
    expect(repository.settings.themeMode, AppThemeMode.dark);
    expect(
      tester
          .widget<PopupMenuButton<AppThemeMode>>(
            find.byType(PopupMenuButton<AppThemeMode>),
          )
          .color,
      const Color(0xFF2C2C2C),
    );

    await tester.tap(find.byKey(const Key('theme-seed-indigo')));
    await tester.pumpAndSettle();
    expect(repository.settings.themeSeed, ThemeSeed.indigo);

    await tester.tap(find.byKey(const Key('theme-seed-monet')));
    await tester.pumpAndSettle();
    expect(repository.settings.themeSeed, ThemeSeed.monet);

    await tester.tap(find.byType(PopupMenuButton<AppLocalePreference>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(repository.settings.localePreference, AppLocalePreference.en);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets(
    'previews backup details and waits for incremental confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = MemorySettingsRepository(
        const AppSettings(localePreference: AppLocalePreference.en),
      );
      final backupService = RecordingBackupImportService();
      await tester.pumpWidget(
        _testApp(repository, backupImportService: backupService),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      final pageScrollable = find
          .descendant(
            of: find.byType(AppPage),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(pageScrollable, const Offset(0, -380));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backup-import-tile')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('backup-preview-sheet')), findsOneWidget);
      expect(find.text('Backup details'), findsOneWidget);
      expect(find.text('ShadowDiary 1.8.2'), findsOneWidget);
      expect(find.text('Diary entries'), findsOneWidget);
      expect(find.text('Archives'), findsWidgets);
      expect(backupService.importModes, isEmpty);
      expect(
        tester
            .widget<SegmentedButton<BackupImportMode>>(
              find.byKey(const Key('backup-import-mode')),
            )
            .selected,
        {BackupImportMode.overwrite},
      );

      final sheetScrollable = find
          .descendant(
            of: find.byKey(const Key('backup-preview-sheet')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(sheetScrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Incremental'));
      await tester.pumpAndSettle();
      expect(
        find.text('Conflicting diaries: 2 will not be imported'),
        findsOneWidget,
      );
      expect(backupService.importModes, isEmpty);
      expect(tester.takeException(), isNull);

      await tester.drag(sheetScrollable, const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backup-import-confirm')));
      await tester.pumpAndSettle();

      expect(backupService.importModes, [BackupImportMode.incremental]);
      expect(
        find.text('Imported 3 diaries and skipped 2 conflicts.'),
        findsOneWidget,
      );
      expect(backupService.discardCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('localizes backup preview and discards it when canceled', (
    tester,
  ) async {
    final repository = MemorySettingsRepository(
      const AppSettings(localePreference: AppLocalePreference.zh),
    );
    final backupService = RecordingBackupImportService();
    await tester.pumpWidget(
      _testApp(repository, backupImportService: backupService),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('backup-import-tile')),
      240,
      scrollable: find
          .descendant(
            of: find.byType(AppPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('backup-import-tile')));
    await tester.pumpAndSettle();

    expect(find.text('备份信息'), findsOneWidget);
    expect(find.text('导出版本'), findsOneWidget);
    expect(find.text('日记篇数'), findsOneWidget);
    expect(find.text('档案数'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('backup-import-cancel')),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('backup-preview-sheet')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('backup-import-cancel')));
    await tester.pumpAndSettle();

    expect(backupService.importModes, isEmpty);
    expect(backupService.discardCount, 1);
  });

  testWidgets('uses a frosted navigation bar without narrow-screen overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = MemorySettingsRepository(
      const AppSettings(localePreference: AppLocalePreference.en),
    );
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byType(FrostedNavigationBar), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(FrostedNavigationBar.blurSigma, 36);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).extendBody,
      isTrue,
    );

    final pageSafeArea = tester.widget<SafeArea>(
      find.byKey(const Key('app-page-safe-area')),
    );
    expect(pageSafeArea.bottom, isFalse);

    final scrollViewBottom = tester
        .getBottomRight(
          find.descendant(
            of: find.byType(AppPage),
            matching: find.byType(CustomScrollView),
          ),
        )
        .dy;
    final navigationBarTop = tester.getTopLeft(find.byType(NavigationBar)).dy;
    expect(scrollViewBottom, greaterThan(navigationBarTop));

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.backgroundColor, Colors.transparent);
    final navigationTheme = NavigationBarTheme.of(
      tester.element(find.byType(NavigationBar)),
    );
    expect(navigationTheme.indicatorColor, const Color(0xFFE4E4E4));
    expect(
      navigationTheme.iconTheme?.resolve({WidgetState.selected})?.color,
      Colors.black,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp(
  MemorySettingsRepository repository, {
  DiaryRepository? diaryRepository,
  ArchiveRepository? archiveRepository,
  BackupImportService? backupImportService,
}) {
  return ProviderScope(
    overrides: [
      appSettingsRepositoryProvider.overrideWithValue(repository),
      initialAppSettingsProvider.overrideWithValue(repository.settings),
      diaryRepositoryProvider.overrideWithValue(
        diaryRepository ?? EmptyDiaryRepository(),
      ),
      archiveRepositoryProvider.overrideWithValue(
        archiveRepository ?? EmptyArchiveRepository(),
      ),
      backupImportServiceProvider.overrideWithValue(
        backupImportService ?? const UnavailableBackupImportService(),
      ),
    ],
    child: const ShadowDiaryApp(),
  );
}

class EmptyArchiveRepository implements ArchiveRepository {
  @override
  Future<void> delete(String id) async {}

  @override
  Future<Archive?> findById(String id) async => null;

  @override
  Future<List<Archive>> listArchives() async => const [];

  @override
  Future<void> save(Archive archive) async {}
}

class RecordingArchiveRepository extends EmptyArchiveRepository {
  final List<Archive> archives = [];

  @override
  Future<void> delete(String id) async {
    archives.removeWhere((archive) => archive.id == id);
  }

  @override
  Future<Archive?> findById(String id) async {
    for (final archive in archives) {
      if (archive.id == id) return archive;
    }
    return null;
  }

  @override
  Future<List<Archive>> listArchives() async => List.unmodifiable(archives);

  @override
  Future<void> save(Archive archive) async {
    archives.removeWhere((value) => value.id == archive.id);
    archives.add(archive);
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

class RecordingDiaryRepository extends EmptyDiaryRepository {
  final List<DateTime> requestedDates = [];

  @override
  Future<DiaryEntry?> findByDate(DateTime date) async {
    requestedDates.add(date);
    return null;
  }
}

class RecordingBackupImportService implements BackupImportService {
  static final preview = BackupImportPreview(
    sessionId: 'preview-session',
    fileName: 'shadow-diary-backup-20260722-143025.zip',
    appName: 'ShadowDiary',
    appVersion: '1.8.2',
    exportedAt: DateTime.utc(2026, 7, 22, 6, 30, 25),
    formatVersion: backupFormatVersion,
    diaryCount: 5,
    archiveCount: 2,
    attachmentCount: 1,
    mediaFileCount: 4,
    conflictDiaryCount: 2,
  );

  final List<BackupImportMode> importModes = [];
  int discardCount = 0;

  @override
  Future<BackupImportPreview?> selectBackup() async => preview;

  @override
  Future<BackupImportResult> importBackup(
    BackupImportPreview preview,
    BackupImportMode mode,
  ) async {
    importModes.add(mode);
    return const BackupImportResult(
      importedDiaryCount: 3,
      importedArchiveCount: 2,
      skippedDiaryCount: 2,
    );
  }

  @override
  Future<void> discardPreview(BackupImportPreview preview) async {
    discardCount++;
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
