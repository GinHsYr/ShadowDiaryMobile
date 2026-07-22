import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/archives/archive.dart';
import 'package:shadow_diary_mobile/core/archives/archive_repository.dart';
import 'package:shadow_diary_mobile/core/services/archive_image_service.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings.dart';
import 'package:shadow_diary_mobile/core/theme/app_theme.dart';
import 'package:shadow_diary_mobile/features/archives/archives_page.dart';
import 'package:shadow_diary_mobile/l10n/app_localizations.dart';

void main() {
  testWidgets('groups archives by pinyin and opens add and edit routes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MemoryArchiveRepository([
      _archive('zhang', '张三', alias: '小张'),
      _archive('alice', 'alice'),
      _archive('number', '2Pac'),
    ]);
    var addCount = 0;
    String? openedId;

    await tester.pumpWidget(
      _testApp(
        repository,
        brightness: Brightness.dark,
        page: ArchivesPage(
          onAddArchive: () async {
            addCount++;
            return false;
          },
          onEditArchive: (id) async {
            openedId = id;
            return false;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('archive-group-A')), findsOneWidget);
    expect(find.byKey(const Key('archive-group-Z')), findsOneWidget);
    expect(find.byKey(const Key('archive-group-#')), findsOneWidget);
    expect(find.byKey(const Key('archive-alphabet-rail')), findsOneWidget);
    expect(find.byKey(const Key('archive-index-Z')), findsOneWidget);
    expect(find.text('小张'), findsOneWidget);
    final avatar = tester.widget<Container>(
      find.byKey(const Key('archive-avatar-zhang')),
    );
    expect((avatar.decoration! as BoxDecoration).shape, BoxShape.circle);
    final addButton = tester.widget<FloatingActionButton>(
      find.byKey(const Key('archives-add-button')),
    );
    expect(addButton.shape, isA<CircleBorder>());

    await tester.tap(find.byKey(const Key('archives-add-button')));
    await tester.pump();
    expect(addCount, 1);

    await tester.tap(find.byKey(const Key('archive-card-zhang')));
    await tester.pump();
    expect(openedId, 'zhang');
    expect(tester.takeException(), isNull);
  });

  testWidgets('reveals delete action and requires confirmation', (
    tester,
  ) async {
    final repository = _MemoryArchiveRepository([_archive('alice', 'Alice')]);
    final imageService = _RecordingArchiveImageService();
    await tester.pumpWidget(
      _testApp(
        repository,
        imageService: imageService,
        page: ArchivesPage(
          onAddArchive: () async => false,
          onEditArchive: (id) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('archive-card-alice'));
    await tester.drag(card, const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(find.byType(SlidableAction), findsOneWidget);

    await tester.tap(find.byKey(const Key('archive-swipe-delete-alice')));
    await tester.pumpAndSettle();
    expect(find.text('Delete archive?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.deletedIds, isEmpty);
    expect(card, findsOneWidget);

    await tester.drag(card, const Offset(-250, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('archive-swipe-delete-alice')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('archive-delete-confirm-button')));
    await tester.pumpAndSettle();

    expect(repository.deletedIds, ['alice']);
    expect(find.byKey(const Key('archive-card-alice')), findsNothing);
  });

  testWidgets('neutral dark archive avatar and add action stay visible', (
    tester,
  ) async {
    final theme = AppTheme.dark(ThemeSeed.neutral);
    final colors = theme.colorScheme;
    final repository = _MemoryArchiveRepository([_archive('alice', 'Alice')]);

    await tester.pumpWidget(
      _testApp(
        repository,
        brightness: Brightness.dark,
        seed: ThemeSeed.neutral,
        page: ArchivesPage(onAddArchive: () async => false),
      ),
    );
    await tester.pumpAndSettle();

    final avatarFinder = find.byKey(const Key('archive-avatar-alice'));
    final avatar = tester.widget<Container>(avatarFinder);
    expect(
      (avatar.decoration! as BoxDecoration).color,
      colors.secondaryContainer,
    );
    final avatarText = tester.widget<Text>(
      find.descendant(of: avatarFinder, matching: find.text('A')),
    );
    expect(avatarText.style?.color, colors.onSecondaryContainer);

    final addButton = find.byKey(const Key('archives-add-button'));
    final addIcon = find.descendant(
      of: addButton,
      matching: find.byIcon(Icons.add_rounded),
    );
    final buttonMaterial = tester
        .element(addIcon)
        .findAncestorWidgetOfExactType<Material>();
    expect(buttonMaterial?.color, colors.primaryContainer);
    expect(
      IconTheme.of(tester.element(addIcon)).color,
      colors.onPrimaryContainer,
    );
    expect(colors.primaryContainer, isNot(Colors.black));
  });

  testWidgets('shows the localized empty and retry states', (tester) async {
    final emptyRepository = _MemoryArchiveRepository(const []);
    await tester.pumpWidget(
      _testApp(
        emptyRepository,
        locale: const Locale('zh'),
        page: ArchivesPage(onAddArchive: () async => false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('还没有档案'), findsOneWidget);
    final emptyState = find.byKey(const Key('archives-empty-state'));
    expect(emptyState, findsOneWidget);
    expect(
      find.descendant(of: emptyState, matching: find.byType(Card)),
      findsNothing,
    );
    expect(find.byKey(const Key('archives-empty-add-button')), findsNothing);
    expect(find.byKey(const Key('archives-add-button')), findsOneWidget);

    final failingRepository = _MemoryArchiveRepository(const [])
      ..loadError = StateError('load failed');
    await tester.pumpWidget(
      _testApp(
        failingRepository,
        page: ArchivesPage(onAddArchive: () async => false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load archives. Try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

Widget _testApp(
  ArchiveRepository repository, {
  required Widget page,
  ArchiveImageService? imageService,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  ThemeSeed seed = ThemeSeed.indigo,
}) {
  return ProviderScope(
    overrides: [
      archiveRepositoryProvider.overrideWithValue(repository),
      if (imageService != null)
        archiveImageServiceProvider.overrideWithValue(imageService),
    ],
    child: MaterialApp(
      locale: locale,
      theme: brightness == Brightness.light
          ? AppTheme.light(seed)
          : AppTheme.dark(seed),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: page),
    ),
  );
}

Archive _archive(String id, String name, {String? alias}) {
  final time = DateTime.fromMillisecondsSinceEpoch(1);
  return Archive(
    id: id,
    name: name,
    alias: alias,
    type: ArchiveType.person,
    createdAt: time,
    updatedAt: time,
  );
}

class _MemoryArchiveRepository implements ArchiveRepository {
  _MemoryArchiveRepository(Iterable<Archive> archives)
    : archives = List.of(archives);

  final List<Archive> archives;
  final List<String> deletedIds = [];
  Object? loadError;

  @override
  Future<void> delete(String id) async {
    deletedIds.add(id);
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
  Future<List<Archive>> listArchives() async {
    if (loadError case final error?) throw error;
    return List.unmodifiable(archives);
  }

  @override
  Future<void> save(Archive archive) async {
    archives.removeWhere((value) => value.id == archive.id);
    archives.add(archive);
  }
}

class _RecordingArchiveImageService implements ArchiveImageService {
  final List<String> deletedPaths = [];

  @override
  Future<void> deleteManagedImages(Iterable<String> paths) async {
    deletedPaths.addAll(paths);
  }

  @override
  Future<List<String>> pickAndStore({required int maxImages}) async => const [];
}
