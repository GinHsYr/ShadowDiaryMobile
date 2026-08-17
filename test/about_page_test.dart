import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_diary_mobile/features/settings/about_page.dart';
import 'package:shadow_diary_mobile/l10n/app_localizations.dart';

void main() {
  testWidgets('shows localized about details and the app icon', (tester) async {
    final launchedUrls = <Uri>[];
    await tester.pumpWidget(
      _testApp(
        const Locale('zh'),
        urlLauncher: (url) async {
          launchedUrls.add(url);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('about-page')), findsOneWidget);
    expect(find.byKey(const Key('about-app-icon')), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    expect(find.text('软件版本: 0.4.5+30'), findsOneWidget);
    expect(find.text('GinHsYr'), findsOneWidget);
    expect(find.text(AboutPage.openSourceUrl), findsOneWidget);
    await tester.tap(find.byKey(const Key('about-repository-link')));
    await tester.tap(find.byKey(const Key('about-author-link')));
    expect(launchedUrls, [
      Uri.parse(AboutPage.openSourceUrl),
      Uri.parse(AboutPage.authorUrl),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the source address within a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text(AboutPage.openSourceUrl), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp(Locale locale, {AboutUrlLauncher? urlLauncher}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: AboutPage(urlLauncher: urlLauncher),
  );
}
