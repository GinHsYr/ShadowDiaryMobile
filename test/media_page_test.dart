import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:shadow_diary_mobile/core/archives/archive.dart';
import 'package:shadow_diary_mobile/core/archives/archive_repository.dart';
import 'package:shadow_diary_mobile/core/diary/diary_entry.dart';
import 'package:shadow_diary_mobile/core/diary/diary_overview.dart';
import 'package:shadow_diary_mobile/core/diary/diary_repository.dart';
import 'package:shadow_diary_mobile/core/media/media_library.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings.dart';
import 'package:shadow_diary_mobile/core/theme/app_theme.dart';
import 'package:shadow_diary_mobile/core/widgets/app_page.dart';
import 'package:shadow_diary_mobile/features/media/media_page.dart';
import 'package:shadow_diary_mobile/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'shows totals, filters the masonry gallery, and opens the source',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime(2026, 7, 22);
      final diaryRepository = _MemoryDiaryRepository([
        DiaryEntry(
          id: 'diary-1',
          title: '雨天',
          content:
              '<p><img src="file:///missing-diary-one.webp"></p>'
              '<p><img src="file:///missing-diary-two.webp"></p>',
          plainContent: '',
          mood: 'calm',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final archiveRepository = _MemoryArchiveRepository([
        Archive(
          id: 'archive-1',
          name: '小满',
          type: ArchiveType.person,
          mainImage: 'missing-archive.webp',
          createdAt: now.subtract(const Duration(days: 1)),
          updatedAt: now.subtract(const Duration(days: 1)),
        ),
      ]);
      MediaItem? openedSource;

      await tester.pumpWidget(
        _testApp(
          diaryRepository: diaryRepository,
          archiveRepository: archiveRepository,
          onOpenSource: (item) async {
            openedSource = item;
            return null;
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('共 3 张图片'), findsOneWidget);
      expect(find.byType(SliverMasonryGrid), findsOneWidget);
      expect(find.byKey(const Key('media-filter-all')), findsOneWidget);
      expect(find.text('全部  3'), findsOneWidget);
      expect(find.text('日记  2'), findsOneWidget);
      expect(find.text('档案  1'), findsOneWidget);
      expect(
        find.byKey(const Key('media-item-diary:diary-1:0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('media-item-diary:diary-1:1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('media-item-archive:archive-1:0')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-150, 0),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('media-filter-archive')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('media-item-diary:diary-1:0')), findsNothing);
      expect(
        find.byKey(const Key('media-item-archive:archive-1:0')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('media-item-archive:archive-1:0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('media-image-viewer')), findsOneWidget);
      expect(find.byType(PhotoViewGallery), findsOneWidget);
      expect(find.text('小满'), findsOneWidget);

      await tester.tap(find.byKey(const Key('media-view-source-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(openedSource?.sourceId, 'archive-1');
      expect(openedSource?.imageSource, 'missing-archive.webp');
      expect(find.byKey(const Key('media-image-viewer')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows the media empty state', (tester) async {
    await tester.pumpWidget(
      _testApp(
        diaryRepository: _MemoryDiaryRepository(const []),
        archiveRepository: _MemoryArchiveRepository(const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有媒体'), findsOneWidget);
    expect(find.text('日记和档案中的图片会汇集到这里。'), findsOneWidget);
    final emptyState = find.byKey(const Key('media-empty-state'));
    expect(emptyState, findsOneWidget);
    expect(
      find.descendant(of: emptyState, matching: find.byType(Card)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: emptyState,
        matching: find.byIcon(Icons.photo_library_rounded),
      ),
      findsOneWidget,
    );
    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.byType(SliverMasonryGrid), findsNothing);
  });
}

Widget _testApp({
  required DiaryRepository diaryRepository,
  required ArchiveRepository archiveRepository,
  OpenMediaSource? onOpenSource,
}) {
  return ProviderScope(
    overrides: [
      diaryRepositoryProvider.overrideWithValue(diaryRepository),
      archiveRepositoryProvider.overrideWithValue(archiveRepository),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh'),
      theme: AppTheme.light(ThemeSeed.neutral),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: MediaPage(onOpenSource: onOpenSource)),
    ),
  );
}

class _MemoryDiaryRepository implements DiaryRepository {
  _MemoryDiaryRepository(this.entries);

  final List<DiaryEntry> entries;

  @override
  Future<DiaryEntry?> findByDate(DateTime date) async => null;

  @override
  Future<DiaryEntry?> findById(String id) async => null;

  @override
  Future<List<DiaryEntry>> listEntries() async => entries;

  @override
  Future<DiaryOverview> loadOverview() async => DiaryOverview.empty;

  @override
  Future<void> save(DiaryEntry entry) async {}
}

class _MemoryArchiveRepository implements ArchiveRepository {
  _MemoryArchiveRepository(this.archives);

  final List<Archive> archives;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<Archive?> findById(String id) async => null;

  @override
  Future<List<Archive>> listArchives() async => archives;

  @override
  Future<void> save(Archive archive) async {}
}
