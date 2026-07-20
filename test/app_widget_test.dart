import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadow_diary_mobile/app/app.dart';
import 'package:shadow_diary_mobile/app/app_ionicons.dart';
import 'package:shadow_diary_mobile/app/router.dart';
import 'package:shadow_diary_mobile/app/shell.dart';
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
    expect(find.text('编辑日记'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
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

Widget _testApp(MemorySettingsRepository repository) {
  return ProviderScope(
    overrides: [
      appSettingsRepositoryProvider.overrideWithValue(repository),
      initialAppSettingsProvider.overrideWithValue(repository.settings),
    ],
    child: const ShadowDiaryApp(),
  );
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
