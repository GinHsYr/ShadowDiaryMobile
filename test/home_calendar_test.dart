import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings.dart';
import 'package:shadow_diary_mobile/core/theme/app_theme.dart';
import 'package:shadow_diary_mobile/features/home/home_page.dart';
import 'package:shadow_diary_mobile/l10n/app_localizations.dart';
import 'package:wheel_slider/wheel_slider.dart';

void main() {
  testWidgets(
    'shows localized calendar controls and monthly writing progress',
    (tester) async {
      await tester.pumpWidget(
        _calendarApp(
          locale: const Locale('zh'),
          diaryDates: [
            DateTime(2026, 7, 1),
            DateTime(2026, 7, 1, 20),
            DateTime(2026, 7, 20),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2026年7月'), findsOneWidget);
      expect(find.text('回到今天'), findsNothing);
      expect(find.text('上周今日'), findsOneWidget);
      expect(find.text('本月写作完成度'), findsOneWidget);
      expect(find.text('已写 2 / 31 天'), findsOneWidget);
      expect(find.text('6.5%'), findsOneWidget);
      expect(
        tester.getCenter(find.byKey(const Key('calendar-shortcut-row'))).dx,
        closeTo(
          tester.getCenter(find.byKey(const Key('home-calendar-card'))).dx,
          0.5,
        ),
      );

      await tester.tap(find.byKey(const Key('calendar-previous-month')));
      await tester.pumpAndSettle();

      expect(find.text('2026年6月'), findsOneWidget);
      expect(find.text('已写 0 / 30 天'), findsOneWidget);

      await tester.tap(find.text('今天').first);
      await tester.pumpAndSettle();

      expect(find.text('2026年7月'), findsOneWidget);
      expect(find.text('已写 2 / 31 天'), findsOneWidget);

      await tester.tap(find.byKey(const Key('calendar-month-picker')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('calendar-month-year-picker')),
        findsOneWidget,
      );
      expect(find.byType(WheelSlider), findsNWidgets(2));
      expect(find.byKey(const Key('calendar-year-wheel')), findsOneWidget);
      expect(find.byKey(const Key('calendar-month-wheel')), findsOneWidget);
      final yearWheel = tester.widget<WheelSlider>(
        find.byKey(const Key('calendar-year-wheel')),
      );
      final monthWheel = tester.widget<WheelSlider>(
        find.byKey(const Key('calendar-month-wheel')),
      );
      expect(yearWheel.selectedNumberStyle?.color, Colors.black);
      expect(yearWheel.horizontal, isFalse);
      expect(monthWheel.horizontal, isFalse);
      expect(
        tester.getCenter(find.text('年份')).dx,
        closeTo(
          tester
              .getCenter(find.byKey(const Key('calendar-year-wheel-field')))
              .dx,
          0.5,
        ),
      );
      expect(
        tester.getCenter(find.text('月份')).dx,
        closeTo(
          tester
              .getCenter(find.byKey(const Key('calendar-month-wheel-field')))
              .dx,
          0.5,
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('calendar-month-wheel')),
          matching: find.text('0'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('calendar-year-wheel-field')),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('calendar-month-wheel-field')),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );

      yearWheel.onValueChanged(2027);
      monthWheel.onValueChanged(7);
      await tester.pump();

      await tester.tap(find.byKey(const Key('calendar-month-picker-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('2027年8月'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('uses English labels and does not overflow on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_calendarApp(locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('July 2026'), findsOneWidget);
    expect(find.text('Back to today'), findsNothing);
    expect(find.text('This day last month'), findsOneWidget);
    expect(find.text('Monthly writing progress'), findsOneWidget);
    expect(find.text('Written 0 / 31 days'), findsOneWidget);
    expect(find.byKey(const Key('home-month-calendar')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('home-calendar-card'))).height,
      lessThan(480),
    );
    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('calendar-progress')),
    );
    expect(progress.color, Colors.black);
    expect(progress.backgroundColor, const Color(0xFFD7D7D7));
    final todayShortcut = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Today'),
    );
    expect(
      todayShortcut.style?.backgroundColor?.resolve(<WidgetState>{}),
      const Color(0xFFF0F0F0),
    );

    await tester.tap(find.byKey(const Key('calendar-month-picker')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-year-wheel')), findsOneWidget);
    expect(find.byKey(const Key('calendar-month-wheel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _calendarApp({
  required Locale locale,
  Iterable<DateTime> diaryDates = const <DateTime>[],
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [...AppLocalizations.localizationsDelegates],
    theme: AppTheme.light(ThemeSeed.neutral),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: HomeCalendar(
            initialDate: DateTime(2026, 7, 20),
            diaryDates: diaryDates,
          ),
        ),
      ),
    ),
  );
}
