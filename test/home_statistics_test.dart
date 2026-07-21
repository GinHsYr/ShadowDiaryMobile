import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings.dart';
import 'package:shadow_diary_mobile/core/theme/app_theme.dart';
import 'package:shadow_diary_mobile/features/home/home_page.dart';
import 'package:shadow_diary_mobile/l10n/app_localizations.dart';

void main() {
  testWidgets('shows localized statistics cards below the calendar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _homeApp(
        locale: const Locale('zh'),
        theme: AppTheme.light(ThemeSeed.neutral),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('你一共写了'), findsOneWidget);
    expect(find.text('连续记录'), findsOneWidget);
    expect(find.text('共写了'), findsOneWidget);
    expect(_metricText(tester, 'diary'), '147 篇日记');
    expect(_metricText(tester, 'streak'), '20 天');
    expect(_metricText(tester, 'character'), '76177 字');

    final calendarBottom = tester
        .getBottomLeft(find.byKey(const Key('home-calendar-card')))
        .dy;
    final statisticsTop = tester
        .getTopLeft(find.byKey(const Key('home-statistics-cards')))
        .dy;
    expect(statisticsTop - calendarBottom, closeTo(AppSpacing.md, 0.1));

    final diarySize = tester.getSize(
      find.byKey(const Key('home-statistics-diary-card')),
    );
    final streakSize = tester.getSize(
      find.byKey(const Key('home-statistics-streak-card')),
    );
    final characterSize = tester.getSize(
      find.byKey(const Key('home-statistics-character-card')),
    );
    expect(diarySize.height, 112);
    expect(streakSize, diarySize);
    expect(characterSize, diarySize);

    final diaryTop = tester
        .getTopLeft(find.byKey(const Key('home-statistics-diary-card')))
        .dy;
    final titleTop = tester
        .getTopLeft(find.byKey(const Key('home-statistics-diary-label')))
        .dy;
    expect(titleTop - diaryTop, closeTo(12, 1));
  });

  testWidgets('keeps English statistics readable on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _homeApp(
        locale: const Locale('en'),
        theme: AppTheme.light(ThemeSeed.teal),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You wrote'), findsOneWidget);
    expect(find.text('Streak'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(_metricText(tester, 'diary'), '147 entries');
    expect(_metricText(tester, 'streak'), '20 days');
    expect(_metricText(tester, 'character'), '76177 characters');
    expect(tester.takeException(), isNull);

    for (final identifier in ['diary', 'streak', 'character']) {
      final label = tester.renderObject<RenderParagraph>(
        find.byKey(Key('home-statistics-$identifier-label')),
      );
      expect(label.didExceedMaxLines, isFalse, reason: identifier);
    }

    final statisticsRect = tester.getRect(
      find.byKey(const Key('home-statistics-cards')),
    );
    final cardRects = [
      tester.getRect(find.byKey(const Key('home-statistics-diary-card'))),
      tester.getRect(find.byKey(const Key('home-statistics-streak-card'))),
      tester.getRect(find.byKey(const Key('home-statistics-character-card'))),
    ];
    expect(cardRects.first.left, statisticsRect.left);
    expect(cardRects.last.right, statisticsRect.right);
    expect(cardRects[0].right, lessThan(cardRects[1].left));
    expect(cardRects[1].right, lessThan(cardRects[2].left));
  });

  testWidgets('uses readable and theme-aware statistic colors', (tester) async {
    final neutralTheme = AppTheme.dark(ThemeSeed.neutral);
    await tester.pumpWidget(_statisticsApp(theme: neutralTheme));
    await tester.pumpAndSettle();

    expect(
      _metricNumberColor(tester, 'diary'),
      neutralTheme.colorScheme.onSurface,
    );
    expect(
      _labelColor(tester, 'diary'),
      neutralTheme.colorScheme.onSurfaceVariant,
    );

    final roseTheme = AppTheme.dark(ThemeSeed.rose);
    await tester.pumpWidget(_statisticsApp(theme: roseTheme));
    await tester.pumpAndSettle();

    expect(_metricNumberColor(tester, 'diary'), roseTheme.colorScheme.primary);
    expect(
      _labelColor(tester, 'diary'),
      roseTheme.colorScheme.onSurfaceVariant,
    );
    final cardMaterial = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(const Key('home-statistics-diary-card')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(cardMaterial.color, roseTheme.cardTheme.color);
  });
}

Widget _homeApp({required Locale locale, required ThemeData theme}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: theme,
    home: const Scaffold(
      body: HomePage(diaryCount: 147, streakDays: 20, characterCount: 76177),
    ),
  );
}

Widget _statisticsApp({required ThemeData theme}) {
  return MaterialApp(
    locale: const Locale('zh'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: theme,
    home: const Scaffold(
      body: Center(
        child: SizedBox(
          width: 560,
          child: HomeStatisticsCards(
            diaryCount: 147,
            streakDays: 20,
            characterCount: 76177,
          ),
        ),
      ),
    ),
  );
}

String _metricText(WidgetTester tester, String identifier) {
  final text = tester.widget<Text>(
    find.byKey(Key('home-statistics-$identifier-value')),
  );
  return text.textSpan!.toPlainText();
}

Color? _metricNumberColor(WidgetTester tester, String identifier) {
  final text = tester.widget<Text>(
    find.byKey(Key('home-statistics-$identifier-value')),
  );
  final span = text.textSpan! as TextSpan;
  return (span.children!.first as TextSpan).style?.color;
}

Color? _labelColor(WidgetTester tester, String identifier) {
  return tester
      .widget<Text>(find.byKey(Key('home-statistics-$identifier-label')))
      .style
      ?.color;
}
