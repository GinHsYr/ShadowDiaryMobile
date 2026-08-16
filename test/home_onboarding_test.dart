import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/core/diary/diary_overview.dart';
import 'package:shadow_diary_mobile/core/diary/diary_repository.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings_controller.dart';
import 'package:shadow_diary_mobile/core/settings/app_settings_repository.dart';
import 'package:shadow_diary_mobile/core/theme/app_theme.dart';
import 'package:shadow_diary_mobile/features/home/home_page.dart';
import 'package:shadow_diary_mobile/l10n/app_localizations.dart';

void main() {
  testWidgets('shows first-use calendar guide and persists dismissal', (
    tester,
  ) async {
    final repository = _MemorySettingsRepository(
      const AppSettings(localePreference: AppLocalePreference.zh),
    );
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-onboarding-guide')), findsOneWidget);
    expect(find.text('开始写第一篇日记'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-onboarding-dismiss')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-onboarding-guide')), findsNothing);
    expect(repository.settings.onboardingCompleted, isTrue);
  });

  testWidgets('tapping a calendar date completes guide and forwards date', (
    tester,
  ) async {
    final repository = _MemorySettingsRepository(
      const AppSettings(localePreference: AppLocalePreference.en),
    );
    DateTime? selectedDate;
    await tester.pumpWidget(
      _testApp(
        repository,
        onCalendarDateSelected: (date) => selectedDate = date,
      ),
    );
    await tester.pumpAndSettle();

    final now = DateUtils.dateOnly(DateTime.now());
    final dateFinder = find.descendant(
      of: find.byKey(const Key('home-month-calendar')),
      matching: find.text('15'),
    );
    expect(dateFinder, findsOneWidget);
    await tester.tap(dateFinder);
    await tester.pumpAndSettle();

    expect(selectedDate, DateTime(now.year, now.month, 15));
    expect(repository.settings.onboardingCompleted, isTrue);
    expect(find.byKey(const Key('home-onboarding-guide')), findsNothing);
  });
}

Widget _testApp(
  _MemorySettingsRepository repository, {
  ValueChanged<DateTime>? onCalendarDateSelected,
}) {
  return ProviderScope(
    overrides: [
      appSettingsRepositoryProvider.overrideWithValue(repository),
      initialAppSettingsProvider.overrideWithValue(repository.settings),
      diaryOverviewProvider.overrideWith((ref) async => DiaryOverview.empty),
    ],
    child: MaterialApp(
      locale: const Locale('zh'),
      theme: AppTheme.light(ThemeSeed.neutral),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: HomePage(onCalendarDateSelected: onCalendarDateSelected),
      ),
    ),
  );
}

class _MemorySettingsRepository implements AppSettingsRepository {
  _MemorySettingsRepository(this.settings);

  AppSettings settings;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings settings) async {
    this.settings = settings;
  }
}
