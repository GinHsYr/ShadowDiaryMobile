import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:shadow_diary_mobile/core/archives/archive.dart';
import 'package:shadow_diary_mobile/core/archives/archive_repository.dart';
import 'package:shadow_diary_mobile/core/services/archive_image_service.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings.dart';
import 'package:shadow_diary_mobile/core/theme/app_theme.dart';
import 'package:shadow_diary_mobile/features/archives/archive_editor_page.dart';
import 'package:shadow_diary_mobile/features/archives/archive_image_viewer.dart';
import 'package:shadow_diary_mobile/l10n/app_localizations.dart';

void main() {
  testWidgets('opens the full-screen image viewer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => FilledButton(
            key: const Key('open-image-viewer'),
            onPressed: () {
              showArchiveImageViewer(
                context,
                images: const ['missing.webp'],
                initialIndex: 0,
              );
            },
            child: const Text('Open image'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-image-viewer')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('archive-image-viewer')), findsOneWidget);
  });

  testWidgets('validates, creates an archive, and returns after save', (
    tester,
  ) async {
    final repository = _MemoryArchiveRepository();
    final imageService = _FakeArchiveImageService([
      'first.webp',
      'second.webp',
    ]);
    await tester.pumpWidget(_testApp(repository, imageService: imageService));
    await tester.tap(find.byKey(const Key('open-archive-editor')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('archive-save-button')));
    await tester.pump();
    expect(find.text('Enter an archive name'), findsWidgets);
    expect(repository.saved, isEmpty);

    await tester.enterText(
      find.byKey(const Key('archive-name-field')),
      'Mountain Club',
    );
    await _addAlias(tester, 'Club');
    await _addAlias(tester, 'Friends');
    expect(find.byKey(const Key('archive-alias-chip-0')), findsOneWidget);
    expect(find.byKey(const Key('archive-alias-chip-1')), findsOneWidget);
    await tester.tap(find.text('Other'));
    await _scrollToEditorWidget(
      tester,
      find.byKey(const Key('archive-add-images-button')),
    );
    await tester.tap(find.byKey(const Key('archive-add-images-button')));
    await tester.pumpAndSettle();

    expect(imageService.requestedLimits, [9]);
    expect(find.byType(MasonryGridView), findsOneWidget);
    expect(find.byKey(const Key('archive-gallery-image-0')), findsOneWidget);
    expect(find.text('2 / 20'), findsOneWidget);

    await tester.tap(find.byKey(const Key('archive-save-button')));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.name, 'Mountain Club');
    expect(repository.saved.single.alias, 'Club,Friends');
    expect(repository.saved.single.type, ArchiveType.other);
    expect(repository.saved.single.images, ['first.webp', 'second.webp']);
    expect(find.byKey(const Key('archive-editor-form')), findsNothing);
    expect(find.text('result:true'), findsOneWidget);
  });

  testWidgets('keeps the main image separate and enforces the total limit', (
    tester,
  ) async {
    final archive = _archive(
      alias: 'Ace,Al',
      mainImage: 'main.webp',
      images: List.generate(19, (index) => 'gallery-$index.webp'),
    );
    final repository = _MemoryArchiveRepository(archive);
    await tester.pumpWidget(_testApp(repository, archiveId: archive.id));
    await tester.tap(find.byKey(const Key('open-archive-editor')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('archive-main-image')), findsOneWidget);
    final mainImageSurface = tester.widget<Material>(
      find.byKey(const Key('archive-main-image-surface')),
    );
    expect(mainImageSurface.shape, isA<CircleBorder>());
    expect(find.text('Ace'), findsOneWidget);
    expect(find.text('Al'), findsOneWidget);
    await tester.tap(find.byKey(const Key('archive-alias-remove-0')));
    await tester.pump();
    expect(find.text('Ace'), findsNothing);
    expect(find.text('Al'), findsOneWidget);
    await _scrollToEditorWidget(
      tester,
      find.byKey(const Key('archive-image-count')),
    );
    expect(find.text('20 / 20'), findsOneWidget);
    expect(find.byKey(const Key('archive-add-images-button')), findsNothing);
    await _scrollToEditorWidget(
      tester,
      find.byKey(const Key('archive-gallery-image-18')),
    );
    expect(find.byKey(const Key('archive-gallery-image-0')), findsOneWidget);
    expect(find.byKey(const Key('archive-gallery-image-18')), findsOneWidget);
  });

  testWidgets('neutral dark editor controls use readable active colors', (
    tester,
  ) async {
    final theme = AppTheme.dark(ThemeSeed.neutral);
    final colors = theme.colorScheme;
    final repository = _MemoryArchiveRepository();

    await tester.pumpWidget(
      _testApp(
        repository,
        brightness: Brightness.dark,
        seed: ThemeSeed.neutral,
      ),
    );
    await tester.tap(find.byKey(const Key('open-archive-editor')));
    await tester.pumpAndSettle();

    final saveFinder = find.byKey(const Key('archive-save-button'));
    final saveButton = tester.widget<FilledButton>(saveFinder);
    final saveStyle = saveButton.defaultStyleOf(tester.element(saveFinder));
    expect(
      saveStyle.backgroundColor?.resolve(const <WidgetState>{}),
      colors.primary,
    );
    expect(
      saveStyle.foregroundColor?.resolve(const <WidgetState>{}),
      colors.onPrimary,
    );
    expect(colors.primary, isNot(Colors.black));

    final personLabel = find.descendant(
      of: find.byKey(const Key('archive-type-selector')),
      matching: find.text('Person'),
    );
    final segmentStyle = TextButtonTheme.of(tester.element(personLabel)).style!;
    const selected = <WidgetState>{WidgetState.selected};
    expect(
      segmentStyle.backgroundColor?.resolve(selected),
      colors.secondaryContainer,
    );
    expect(
      segmentStyle.foregroundColor?.resolve(selected),
      colors.onSecondaryContainer,
    );
    expect(colors.secondaryContainer, isNot(Colors.black));
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirms unsaved exit and cleans newly selected images', (
    tester,
  ) async {
    final repository = _MemoryArchiveRepository();
    final imageService = _FakeArchiveImageService(['new-image.webp']);
    await tester.pumpWidget(_testApp(repository, imageService: imageService));
    await tester.tap(find.byKey(const Key('open-archive-editor')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('archive-name-field')),
      'Draft',
    );
    await _scrollToEditorWidget(
      tester,
      find.byKey(const Key('archive-add-images-button')),
    );
    await tester.tap(find.byKey(const Key('archive-add-images-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('archive-editor-back-button')));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('archive-editor-form')), findsOneWidget);
    expect(imageService.deletedPaths, isEmpty);

    await tester.tap(find.byKey(const Key('archive-editor-back-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('archive-discard-confirm-button')));
    await tester.pumpAndSettle();

    expect(imageService.deletedPaths, ['new-image.webp']);
    expect(find.text('result:null'), findsOneWidget);
  });

  testWidgets('previews gallery images and deletes an existing archive', (
    tester,
  ) async {
    final archive = _archive(images: const ['missing.webp']);
    final repository = _MemoryArchiveRepository(archive);
    final imageService = _FakeArchiveImageService(const []);
    await tester.pumpWidget(
      _testApp(
        repository,
        archiveId: archive.id,
        imageService: imageService,
        brightness: Brightness.dark,
      ),
    );
    await tester.tap(find.byKey(const Key('open-archive-editor')));
    await tester.pumpAndSettle();

    await _scrollToEditorWidget(
      tester,
      find.byKey(const Key('archive-gallery-image-0')),
    );
    final previewTarget = find.byKey(const Key('archive-gallery-preview-0'));
    expect(previewTarget.hitTestable(), findsOneWidget);
    await tester.tap(previewTarget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('archive-image-viewer')), findsOneWidget);
    expect(find.byType(PhotoViewGallery), findsOneWidget);
    await tester.tap(find.byKey(const Key('archive-image-viewer-close')));
    await tester.pumpAndSettle();

    await _scrollToEditorWidget(
      tester,
      find.byKey(const Key('archive-editor-delete-button')),
    );
    await tester.tap(find.byKey(const Key('archive-editor-delete-button')));
    await tester.pumpAndSettle();
    expect(find.text('Delete archive?'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('archive-editor-delete-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(repository.deletedIds, [archive.id]);
    expect(imageService.deletedPaths, contains('missing.webp'));
    expect(find.text('result:true'), findsOneWidget);
  });

  testWidgets('does not overflow at 320 logical pixels', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MemoryArchiveRepository();
    await tester.pumpWidget(_testApp(repository));
    await tester.tap(find.byKey(const Key('open-archive-editor')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('archive-type-selector')), findsOneWidget);
    await _scrollToEditorWidget(
      tester,
      find.byKey(const Key('archive-masonry-gallery')),
    );
    expect(find.byType(MasonryGridView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reveals the archive image targeted from media', (tester) async {
    const targetPath = 'missing-target.webp';
    final archive = _archive(
      images: const ['first.webp', targetPath, 'third.webp'],
    );
    await tester.pumpWidget(
      _testApp(
        _MemoryArchiveRepository(archive),
        archiveId: archive.id,
        initialImagePath: targetPath,
      ),
    );
    await tester.tap(find.byKey(const Key('open-archive-editor')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('archive-source-image-target')),
      findsOneWidget,
    );
    final targetCenter = tester.getCenter(
      find.byKey(const Key('archive-source-image-target')),
    );
    expect(targetCenter.dy, inInclusiveRange(0, 600));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _scrollToEditorWidget(WidgetTester tester, Finder target) async {
  final list = find.byType(ListView);
  for (var attempt = 0; attempt < 12 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(list, const Offset(0, -240));
    await tester.pump(const Duration(milliseconds: 120));
  }
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _addAlias(WidgetTester tester, String alias) async {
  await tester.tap(find.byKey(const Key('archive-alias-add-button')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('archive-alias-dialog-field')),
    alias,
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('archive-alias-dialog-confirm')));
  await tester.pumpAndSettle();
}

Widget _testApp(
  _MemoryArchiveRepository repository, {
  String? archiveId,
  String? initialImagePath,
  ArchiveImageService? imageService,
  Brightness brightness = Brightness.light,
  ThemeSeed seed = ThemeSeed.teal,
}) {
  return ProviderScope(
    overrides: [
      archiveRepositoryProvider.overrideWithValue(repository),
      if (imageService != null)
        archiveImageServiceProvider.overrideWithValue(imageService),
    ],
    child: MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.light(seed)
          : AppTheme.dark(seed),
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: _EditorLauncher(
        archiveId: archiveId,
        initialImagePath: initialImagePath,
      ),
    ),
  );
}

class _EditorLauncher extends StatefulWidget {
  const _EditorLauncher({
    required this.archiveId,
    required this.initialImagePath,
  });

  final String? archiveId;
  final String? initialImagePath;

  @override
  State<_EditorLauncher> createState() => _EditorLauncherState();
}

class _EditorLauncherState extends State<_EditorLauncher> {
  Object? _result;
  bool _hasResult = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              key: const Key('open-archive-editor'),
              onPressed: () async {
                final result = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute<Object?>(
                    builder: (context) => ArchiveEditorPage(
                      archiveId: widget.archiveId,
                      initialImagePath: widget.initialImagePath,
                    ),
                  ),
                );
                if (mounted) {
                  setState(() {
                    _result = result;
                    _hasResult = true;
                  });
                }
              },
              child: const Text('Open'),
            ),
            if (_hasResult) Text('result:$_result'),
          ],
        ),
      ),
    );
  }
}

Archive _archive({
  String? alias,
  String? mainImage,
  List<String> images = const [],
}) {
  final time = DateTime.fromMillisecondsSinceEpoch(1);
  return Archive(
    id: 'archive-1',
    name: 'Alice',
    alias: alias,
    type: ArchiveType.person,
    mainImage: mainImage,
    images: images,
    createdAt: time,
    updatedAt: time,
  );
}

class _MemoryArchiveRepository implements ArchiveRepository {
  _MemoryArchiveRepository([this.archive]);

  Archive? archive;
  final List<Archive> saved = [];
  final List<String> deletedIds = [];

  @override
  Future<void> delete(String id) async {
    deletedIds.add(id);
    archive = null;
  }

  @override
  Future<Archive?> findById(String id) async =>
      archive?.id == id ? archive : null;

  @override
  Future<List<Archive>> listArchives() async {
    return archive == null ? const [] : [archive!];
  }

  @override
  Future<void> save(Archive value) async {
    saved.add(value);
    archive = value;
  }
}

class _FakeArchiveImageService implements ArchiveImageService {
  _FakeArchiveImageService(this.images);

  final List<String> images;
  final List<int> requestedLimits = [];
  final List<String> deletedPaths = [];

  @override
  Future<void> deleteManagedImages(Iterable<String> paths) async {
    deletedPaths.addAll(paths);
  }

  @override
  Future<List<String>> pickAndStore({required int maxImages}) async {
    requestedLimits.add(maxImages);
    return images.take(maxImages).toList(growable: false);
  }
}
