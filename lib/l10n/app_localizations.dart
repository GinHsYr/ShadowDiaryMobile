import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'影迹'**
  String get appName;

  /// No description provided for @navigationHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get navigationHome;

  /// No description provided for @navigationArchives.
  ///
  /// In zh, this message translates to:
  /// **'档案'**
  String get navigationArchives;

  /// No description provided for @navigationMedia.
  ///
  /// In zh, this message translates to:
  /// **'媒体'**
  String get navigationMedia;

  /// No description provided for @navigationSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navigationSettings;

  /// No description provided for @newDiary.
  ///
  /// In zh, this message translates to:
  /// **'新建日记'**
  String get newDiary;

  /// No description provided for @homeGreeting.
  ///
  /// In zh, this message translates to:
  /// **'你好，准备写点什么？'**
  String get homeGreeting;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'从今天开始记录'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In zh, this message translates to:
  /// **'日历、统计和最近日记将在后续功能阶段加入。'**
  String get homeEmptyBody;

  /// No description provided for @calendarToday.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get calendarToday;

  /// No description provided for @calendarYesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get calendarYesterday;

  /// No description provided for @calendarLastWeekSameDay.
  ///
  /// In zh, this message translates to:
  /// **'上周今日'**
  String get calendarLastWeekSameDay;

  /// No description provided for @calendarLastMonthSameDay.
  ///
  /// In zh, this message translates to:
  /// **'上月今日'**
  String get calendarLastMonthSameDay;

  /// No description provided for @calendarHasDiary.
  ///
  /// In zh, this message translates to:
  /// **'有日记'**
  String get calendarHasDiary;

  /// No description provided for @calendarMonthlyProgress.
  ///
  /// In zh, this message translates to:
  /// **'本月写作完成度'**
  String get calendarMonthlyProgress;

  /// No description provided for @calendarSelectMonth.
  ///
  /// In zh, this message translates to:
  /// **'选择年月'**
  String get calendarSelectMonth;

  /// No description provided for @calendarYear.
  ///
  /// In zh, this message translates to:
  /// **'年份'**
  String get calendarYear;

  /// No description provided for @calendarMonth.
  ///
  /// In zh, this message translates to:
  /// **'月份'**
  String get calendarMonth;

  /// No description provided for @calendarWrittenDays.
  ///
  /// In zh, this message translates to:
  /// **'已写 {writtenDays} / {totalDays} 天'**
  String calendarWrittenDays(int writtenDays, int totalDays);

  /// No description provided for @archivesEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有档案'**
  String get archivesEmptyTitle;

  /// No description provided for @archivesEmptyBody.
  ///
  /// In zh, this message translates to:
  /// **'人物与其他档案会在这里集中整理。'**
  String get archivesEmptyBody;

  /// No description provided for @mediaEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有媒体'**
  String get mediaEmptyTitle;

  /// No description provided for @mediaEmptyBody.
  ///
  /// In zh, this message translates to:
  /// **'日记和档案中的图片会汇集到这里。'**
  String get mediaEmptyBody;

  /// No description provided for @settingsAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeMode.
  ///
  /// In zh, this message translates to:
  /// **'显示模式'**
  String get settingsThemeMode;

  /// No description provided for @settingsThemeColor.
  ///
  /// In zh, this message translates to:
  /// **'主题色'**
  String get settingsThemeColor;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// No description provided for @settingsServices.
  ///
  /// In zh, this message translates to:
  /// **'服务'**
  String get settingsServices;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @colorNeutral.
  ///
  /// In zh, this message translates to:
  /// **'中性黑'**
  String get colorNeutral;

  /// No description provided for @colorIndigo.
  ///
  /// In zh, this message translates to:
  /// **'靛蓝'**
  String get colorIndigo;

  /// No description provided for @colorTeal.
  ///
  /// In zh, this message translates to:
  /// **'青绿'**
  String get colorTeal;

  /// No description provided for @colorRose.
  ///
  /// In zh, this message translates to:
  /// **'玫红'**
  String get colorRose;

  /// No description provided for @colorMonet.
  ///
  /// In zh, this message translates to:
  /// **'莫奈取色'**
  String get colorMonet;

  /// No description provided for @languageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageSystem;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @biometricLock.
  ///
  /// In zh, this message translates to:
  /// **'生物识别锁'**
  String get biometricLock;

  /// No description provided for @lanSync.
  ///
  /// In zh, this message translates to:
  /// **'局域网同步'**
  String get lanSync;

  /// No description provided for @notConfigured.
  ///
  /// In zh, this message translates to:
  /// **'尚未配置'**
  String get notConfigured;

  /// No description provided for @editorNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建日记'**
  String get editorNewTitle;

  /// No description provided for @editorEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑日记'**
  String get editorEditTitle;

  /// No description provided for @editorPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'富文本编辑器将在后续功能阶段接入。'**
  String get editorPlaceholder;

  /// No description provided for @bootstrapFailed.
  ///
  /// In zh, this message translates to:
  /// **'影迹启动失败'**
  String get bootstrapFailed;

  /// No description provided for @bootstrapFailedHint.
  ///
  /// In zh, this message translates to:
  /// **'无法初始化本地数据库，请重新启动应用。'**
  String get bootstrapFailedHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
