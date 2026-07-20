import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/app_settings_controller.dart';
import '../core/settings/app_settings.dart';
import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';

class ShadowDiaryApp extends ConsumerWidget {
  const ShadowDiaryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final router = ref.watch(appRouterProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context).appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(
            settings.themeSeed,
            dynamicColorScheme: lightDynamic,
          ),
          darkTheme: AppTheme.dark(
            settings.themeSeed,
            dynamicColorScheme: darkDynamic,
          ),
          themeMode: settings.themeMode.materialThemeMode,
          locale: settings.localePreference.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          localeListResolutionCallback: (locales, supportedLocales) {
            for (final locale in locales ?? const <Locale>[]) {
              for (final supported in supportedLocales) {
                if (locale.languageCode == supported.languageCode) {
                  return supported;
                }
              }
            }
            return const Locale('zh');
          },
          routerConfig: router,
        );
      },
    );
  }
}

class BootstrapFailureApp extends StatelessWidget {
  const BootstrapFailureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(ThemeSeed.neutral),
      home: const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, size: 48),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    '影迹 / ShadowDiary',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    '无法初始化本地数据库，请重新启动应用。\n'
                    'The local database could not be initialized.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
