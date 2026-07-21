import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/diary/diary_entry.dart';
import 'package:shadow_diary_mobile/core/diary/diary_overview.dart';
import 'package:shadow_diary_mobile/core/diary/diary_repository.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings.dart';
import 'package:shadow_diary_mobile/core/theme/app_theme.dart';
import 'package:shadow_diary_mobile/features/editor/editor_page.dart';
import 'package:shadow_diary_mobile/l10n/app_localizations.dart';

void main() {
  testWidgets('collapses and expands the easy date day picker', (tester) async {
    final repository = MemoryDiaryRepository();
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byType(EasyDateTimeLinePicker), findsOneWidget);
    expect(find.byKey(const Key('editor-day-picker')), findsOneWidget);

    await tester.tap(find.byKey(const Key('editor-date-picker-toggle')));
    await tester.pumpAndSettle();
    expect(find.byType(EasyDateTimeLinePicker), findsNothing);

    await tester.tap(find.byKey(const Key('editor-date-picker-toggle')));
    await tester.pumpAndSettle();
    expect(find.byType(EasyDateTimeLinePicker), findsOneWidget);
  });

  testWidgets('date selection loads the diary for that date', (tester) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final anotherDay = today.subtract(const Duration(days: 3));
    final repository = MemoryDiaryRepository([
      _entry('today', today, 'Today title', '<p>Today body</p>', 'Today body'),
      _entry(
        'another',
        anotherDay,
        'Another title',
        '<p>Another body</p>',
        'Another body',
      ),
    ]);
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(_titleText(tester), 'Today title');
    expect(_bodyText(tester), contains('Today body'));
    expect(
      find.byKey(Key('editor-calendar-diary-${_dayKey(today)}')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('editor-title-field')),
      'Saved before switching',
    );

    final picker = tester.widget<EasyDateTimeLinePicker>(
      find.byType(EasyDateTimeLinePicker),
    );
    picker.onDateChange!(anotherDay);
    await tester.pumpAndSettle();

    expect(_titleText(tester), 'Another title');
    expect(_bodyText(tester), contains('Another body'));
    expect(
      (await repository.findById('today'))?.title,
      'Saved before switching',
    );
  });

  testWidgets('automatically saves title, mood, and Quill HTML', (
    tester,
  ) async {
    final repository = MemoryDiaryRepository();
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('editor-title-field')),
      'A saved day',
    );
    await tester.tap(find.byKey(const Key('editor-mood-happy')));
    final editor = tester.widget<QuillEditor>(
      find.byKey(const Key('editor-quill-editor')),
    );
    editor.controller.document.insert(0, 'Rich body');

    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    expect(repository.entries, hasLength(1));
    final saved = repository.entries.single;
    expect(saved.title, 'A saved day');
    expect(saved.mood, 'happy');
    expect(saved.plainContent, 'Rich body');
    expect(saved.content, contains('Rich body'));
    expect(saved.content, contains('<p>'));
    final today = DateUtils.dateOnly(DateTime.now());
    expect(
      find.byKey(Key('editor-calendar-diary-${_dayKey(today)}')),
      findsOneWidget,
    );
  });

  testWidgets('does not create or mark a mood-only empty diary', (
    tester,
  ) async {
    final repository = MemoryDiaryRepository();
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editor-mood-happy')));
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    final today = DateUtils.dateOnly(DateTime.now());
    expect(repository.entries, isEmpty);
    expect(
      find.byKey(Key('editor-calendar-diary-${_dayKey(today)}')),
      findsNothing,
    );
  });

  testWidgets('shows the requested toolbar only above the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(_testApp(MemoryDiaryRepository()));
    await tester.pumpAndSettle();

    const toolbarKey = Key('editor-keyboard-toolbar');
    expect(find.byKey(toolbarKey), findsNothing);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(find.byKey(toolbarKey), findsOneWidget);
    final toolbar = tester.widget<QuillSimpleToolbar>(find.byKey(toolbarKey));
    expect(toolbar.config.showListNumbers, isFalse);
    expect(toolbar.config.showListBullets, isFalse);
    expect(toolbar.config.showLeftAlignment, isTrue);
    expect(toolbar.config.showCenterAlignment, isTrue);
    expect(toolbar.config.showRightAlignment, isFalse);
    expect(toolbar.config.showJustifyAlignment, isFalse);
    expect(toolbar.config.showQuote, isTrue);

    final attributes = tester
        .widgetList<QuillToolbarToggleStyleButton>(
          find.byType(QuillToolbarToggleStyleButton),
        )
        .map((button) => button.attribute)
        .toList();
    expect(
      attributes,
      containsAll(<Attribute>[
        Attribute.leftAlignment,
        Attribute.centerAlignment,
        Attribute.blockQuote,
      ]),
    );
    expect(attributes, isNot(contains(Attribute.rightAlignment)));
    expect(attributes, isNot(contains(Attribute.justifyAlignment)));
    expect(attributes, isNot(contains(Attribute.ol)));
    expect(attributes, isNot(contains(Attribute.ul)));

    expect(tester.getBottomLeft(find.byKey(toolbarKey)).dy, closeTo(340, 1));
    expect(tester.takeException(), isNull);

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(find.byKey(toolbarKey), findsNothing);
  });

  testWidgets('editor has no overflow on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(MemoryDiaryRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('editor-title-field')), findsOneWidget);
    expect(find.byKey(const Key('editor-quill-editor')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp(MemoryDiaryRepository repository) {
  return ProviderScope(
    overrides: [diaryRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      theme: AppTheme.light(ThemeSeed.neutral),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
        EasyDateTimelineLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const EditorPage(),
    ),
  );
}

String _titleText(WidgetTester tester) {
  return tester
      .widget<TextField>(find.byKey(const Key('editor-title-field')))
      .controller!
      .text;
}

String _bodyText(WidgetTester tester) {
  return tester
      .widget<QuillEditor>(find.byKey(const Key('editor-quill-editor')))
      .controller
      .document
      .toPlainText();
}

DiaryEntry _entry(
  String id,
  DateTime date,
  String title,
  String content,
  String plainContent,
) {
  return DiaryEntry(
    id: id,
    title: title,
    content: content,
    plainContent: plainContent,
    mood: 'calm',
    createdAt: date,
    updatedAt: date,
  );
}

class MemoryDiaryRepository implements DiaryRepository {
  MemoryDiaryRepository([Iterable<DiaryEntry> initialEntries = const []])
    : entries = List<DiaryEntry>.from(initialEntries);

  final List<DiaryEntry> entries;

  @override
  Future<DiaryEntry?> findByDate(DateTime date) async {
    for (final entry in entries.reversed) {
      if (DateUtils.isSameDay(entry.createdAt, date)) return entry;
    }
    return null;
  }

  @override
  Future<DiaryEntry?> findById(String id) async {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  @override
  Future<DiaryOverview> loadOverview() async {
    return calculateDiaryOverview(
      entries.map(
        (entry) => (
          createdAt: entry.createdAt,
          title: entry.title,
          plainContent: entry.plainContent,
        ),
      ),
      today: DateTime.now(),
    );
  }

  @override
  Future<void> save(DiaryEntry entry) async {
    final index = entries.indexWhere((candidate) => candidate.id == entry.id);
    if (index == -1) {
      entries.add(entry);
    } else {
      entries[index] = entry;
    }
  }
}

int _dayKey(DateTime date) {
  return date.year * 10000 + date.month * 100 + date.day;
}
