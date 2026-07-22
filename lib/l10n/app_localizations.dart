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

  /// No description provided for @homeStatisticsDiaryLabel.
  ///
  /// In zh, this message translates to:
  /// **'你一共写了'**
  String get homeStatisticsDiaryLabel;

  /// No description provided for @homeStatisticsDiaryUnit.
  ///
  /// In zh, this message translates to:
  /// **'篇日记'**
  String get homeStatisticsDiaryUnit;

  /// No description provided for @homeStatisticsStreakLabel.
  ///
  /// In zh, this message translates to:
  /// **'连续记录'**
  String get homeStatisticsStreakLabel;

  /// No description provided for @homeStatisticsStreakUnit.
  ///
  /// In zh, this message translates to:
  /// **'天'**
  String get homeStatisticsStreakUnit;

  /// No description provided for @homeStatisticsCharacterLabel.
  ///
  /// In zh, this message translates to:
  /// **'共写了'**
  String get homeStatisticsCharacterLabel;

  /// No description provided for @homeStatisticsCharacterUnit.
  ///
  /// In zh, this message translates to:
  /// **'字'**
  String get homeStatisticsCharacterUnit;

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

  /// No description provided for @archiveAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加档案'**
  String get archiveAdd;

  /// No description provided for @archiveTypePerson.
  ///
  /// In zh, this message translates to:
  /// **'人物'**
  String get archiveTypePerson;

  /// No description provided for @archiveTypeOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get archiveTypeOther;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @archiveDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除档案？'**
  String get archiveDeleteTitle;

  /// No description provided for @archiveDeleteMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除“{name}”吗？此操作无法撤销。'**
  String archiveDeleteMessage(String name);

  /// No description provided for @archiveDeleteAction.
  ///
  /// In zh, this message translates to:
  /// **'删除这个档案'**
  String get archiveDeleteAction;

  /// No description provided for @archiveDeleteError.
  ///
  /// In zh, this message translates to:
  /// **'无法删除档案，请重试。'**
  String get archiveDeleteError;

  /// No description provided for @archiveLoadError.
  ///
  /// In zh, this message translates to:
  /// **'无法加载档案，请重试。'**
  String get archiveLoadError;

  /// No description provided for @archiveEditorNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加档案'**
  String get archiveEditorNewTitle;

  /// No description provided for @archiveEditorEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑档案'**
  String get archiveEditorEditTitle;

  /// No description provided for @archiveSaving.
  ///
  /// In zh, this message translates to:
  /// **'保存中'**
  String get archiveSaving;

  /// No description provided for @archiveSaveError.
  ///
  /// In zh, this message translates to:
  /// **'无法保存档案，请重试。'**
  String get archiveSaveError;

  /// No description provided for @archiveMainImage.
  ///
  /// In zh, this message translates to:
  /// **'主图'**
  String get archiveMainImage;

  /// No description provided for @archiveChooseMainImage.
  ///
  /// In zh, this message translates to:
  /// **'选择主图'**
  String get archiveChooseMainImage;

  /// No description provided for @archiveChangeMainImage.
  ///
  /// In zh, this message translates to:
  /// **'更换主图'**
  String get archiveChangeMainImage;

  /// No description provided for @archiveName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get archiveName;

  /// No description provided for @archiveNameHint.
  ///
  /// In zh, this message translates to:
  /// **'输入档案名称'**
  String get archiveNameHint;

  /// No description provided for @archiveNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入档案名称'**
  String get archiveNameRequired;

  /// No description provided for @archiveAlias.
  ///
  /// In zh, this message translates to:
  /// **'别名'**
  String get archiveAlias;

  /// No description provided for @archiveAliasHint.
  ///
  /// In zh, this message translates to:
  /// **'输入一个别名'**
  String get archiveAliasHint;

  /// No description provided for @archiveAddAlias.
  ///
  /// In zh, this message translates to:
  /// **'添加别名'**
  String get archiveAddAlias;

  /// No description provided for @archiveAddAliasAction.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get archiveAddAliasAction;

  /// No description provided for @archiveRemoveAlias.
  ///
  /// In zh, this message translates to:
  /// **'移除别名'**
  String get archiveRemoveAlias;

  /// No description provided for @archiveAliasDuplicate.
  ///
  /// In zh, this message translates to:
  /// **'这个别名已经存在'**
  String get archiveAliasDuplicate;

  /// No description provided for @archiveType.
  ///
  /// In zh, this message translates to:
  /// **'档案类型'**
  String get archiveType;

  /// No description provided for @archiveDescription.
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get archiveDescription;

  /// No description provided for @archiveDescriptionHint.
  ///
  /// In zh, this message translates to:
  /// **'记录与这个档案有关的信息'**
  String get archiveDescriptionHint;

  /// No description provided for @archiveGallery.
  ///
  /// In zh, this message translates to:
  /// **'图库'**
  String get archiveGallery;

  /// No description provided for @archiveImageCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} / {max}'**
  String archiveImageCount(int count, int max);

  /// No description provided for @archiveAddImages.
  ///
  /// In zh, this message translates to:
  /// **'添加图片'**
  String get archiveAddImages;

  /// No description provided for @archiveRemoveImage.
  ///
  /// In zh, this message translates to:
  /// **'移除图片'**
  String get archiveRemoveImage;

  /// No description provided for @archiveImageLimit.
  ///
  /// In zh, this message translates to:
  /// **'每个档案最多保存 {maxImages} 张图片（含主图）。'**
  String archiveImageLimit(int maxImages);

  /// No description provided for @archiveImageAddError.
  ///
  /// In zh, this message translates to:
  /// **'添加图片失败，请重试。'**
  String get archiveImageAddError;

  /// No description provided for @archiveImageMissing.
  ///
  /// In zh, this message translates to:
  /// **'图片不可用'**
  String get archiveImageMissing;

  /// No description provided for @archiveImagePosition.
  ///
  /// In zh, this message translates to:
  /// **'第 {index} 张，共 {total} 张'**
  String archiveImagePosition(int index, int total);

  /// No description provided for @archiveDiscardTitle.
  ///
  /// In zh, this message translates to:
  /// **'放弃修改？'**
  String get archiveDiscardTitle;

  /// No description provided for @archiveDiscardMessage.
  ///
  /// In zh, this message translates to:
  /// **'尚未保存的修改和新添加的图片将会丢失。'**
  String get archiveDiscardMessage;

  /// No description provided for @archiveContinueEditing.
  ///
  /// In zh, this message translates to:
  /// **'继续编辑'**
  String get archiveContinueEditing;

  /// No description provided for @archiveDiscardAction.
  ///
  /// In zh, this message translates to:
  /// **'放弃修改'**
  String get archiveDiscardAction;

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

  /// No description provided for @mediaImageTotal.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 张图片'**
  String mediaImageTotal(int count);

  /// No description provided for @mediaFilterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get mediaFilterAll;

  /// No description provided for @mediaFilterDiary.
  ///
  /// In zh, this message translates to:
  /// **'日记'**
  String get mediaFilterDiary;

  /// No description provided for @mediaFilterArchive.
  ///
  /// In zh, this message translates to:
  /// **'档案'**
  String get mediaFilterArchive;

  /// No description provided for @mediaFilteredEmpty.
  ///
  /// In zh, this message translates to:
  /// **'这个分类中还没有图片'**
  String get mediaFilteredEmpty;

  /// No description provided for @mediaLoadError.
  ///
  /// In zh, this message translates to:
  /// **'无法加载媒体，请重试。'**
  String get mediaLoadError;

  /// No description provided for @mediaImageMissing.
  ///
  /// In zh, this message translates to:
  /// **'图片不可用'**
  String get mediaImageMissing;

  /// No description provided for @mediaUntitledDiary.
  ///
  /// In zh, this message translates to:
  /// **'未命名日记'**
  String get mediaUntitledDiary;

  /// No description provided for @mediaViewSource.
  ///
  /// In zh, this message translates to:
  /// **'查看出处'**
  String get mediaViewSource;

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

  /// No description provided for @settingsSecurity.
  ///
  /// In zh, this message translates to:
  /// **'安全'**
  String get settingsSecurity;

  /// No description provided for @settingsData.
  ///
  /// In zh, this message translates to:
  /// **'数据'**
  String get settingsData;

  /// No description provided for @settingsServices.
  ///
  /// In zh, this message translates to:
  /// **'服务'**
  String get settingsServices;

  /// No description provided for @backupImport.
  ///
  /// In zh, this message translates to:
  /// **'导入备份'**
  String get backupImport;

  /// No description provided for @backupImportDescription.
  ///
  /// In zh, this message translates to:
  /// **'从 ShadowDiary ZIP 备份恢复日记和档案'**
  String get backupImportDescription;

  /// No description provided for @backupReading.
  ///
  /// In zh, this message translates to:
  /// **'正在读取备份…'**
  String get backupReading;

  /// No description provided for @backupPreviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'备份信息'**
  String get backupPreviewTitle;

  /// No description provided for @backupFileName.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get backupFileName;

  /// No description provided for @backupAppVersion.
  ///
  /// In zh, this message translates to:
  /// **'导出版本'**
  String get backupAppVersion;

  /// No description provided for @backupExportedAt.
  ///
  /// In zh, this message translates to:
  /// **'导出时间'**
  String get backupExportedAt;

  /// No description provided for @backupFormatVersion.
  ///
  /// In zh, this message translates to:
  /// **'格式版本'**
  String get backupFormatVersion;

  /// No description provided for @backupDiaryCount.
  ///
  /// In zh, this message translates to:
  /// **'日记篇数'**
  String get backupDiaryCount;

  /// No description provided for @backupArchiveCount.
  ///
  /// In zh, this message translates to:
  /// **'档案数'**
  String get backupArchiveCount;

  /// No description provided for @backupAttachmentCount.
  ///
  /// In zh, this message translates to:
  /// **'附件数'**
  String get backupAttachmentCount;

  /// No description provided for @backupMediaCount.
  ///
  /// In zh, this message translates to:
  /// **'媒体文件数'**
  String get backupMediaCount;

  /// No description provided for @backupImportMode.
  ///
  /// In zh, this message translates to:
  /// **'导入方式'**
  String get backupImportMode;

  /// No description provided for @backupOverwrite.
  ///
  /// In zh, this message translates to:
  /// **'覆盖导入'**
  String get backupOverwrite;

  /// No description provided for @backupOverwriteDescription.
  ///
  /// In zh, this message translates to:
  /// **'清除当前日记和档案，再恢复这份备份。当前应用设置不会改变。'**
  String get backupOverwriteDescription;

  /// No description provided for @backupIncremental.
  ///
  /// In zh, this message translates to:
  /// **'增量导入'**
  String get backupIncremental;

  /// No description provided for @backupIncrementalDescription.
  ///
  /// In zh, this message translates to:
  /// **'只导入本机尚未写过日记的日期，保留现有日记、档案和设置。'**
  String get backupIncrementalDescription;

  /// No description provided for @backupConflictCount.
  ///
  /// In zh, this message translates to:
  /// **'冲突日记'**
  String get backupConflictCount;

  /// No description provided for @backupConflictDiaryCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 篇不会导入'**
  String backupConflictDiaryCount(int count);

  /// No description provided for @backupStartImport.
  ///
  /// In zh, this message translates to:
  /// **'开始导入'**
  String get backupStartImport;

  /// No description provided for @backupImporting.
  ///
  /// In zh, this message translates to:
  /// **'正在导入备份…'**
  String get backupImporting;

  /// No description provided for @backupOverwriteSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已导入 {diaryCount} 篇日记和 {archiveCount} 个档案。'**
  String backupOverwriteSuccess(int diaryCount, int archiveCount);

  /// No description provided for @backupIncrementalSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已导入 {diaryCount} 篇日记，跳过 {skippedCount} 篇冲突日记。'**
  String backupIncrementalSuccess(int diaryCount, int skippedCount);

  /// No description provided for @backupUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'此设备暂不支持导入备份。'**
  String get backupUnavailable;

  /// No description provided for @backupInvalid.
  ///
  /// In zh, this message translates to:
  /// **'这不是有效的 ShadowDiary 备份文件。'**
  String get backupInvalid;

  /// No description provided for @backupUnsupportedFormat.
  ///
  /// In zh, this message translates to:
  /// **'此备份格式版本不受支持。'**
  String get backupUnsupportedFormat;

  /// No description provided for @backupMissingKey.
  ///
  /// In zh, this message translates to:
  /// **'备份中缺少数据库密钥文件。'**
  String get backupMissingKey;

  /// No description provided for @backupUnreadable.
  ///
  /// In zh, this message translates to:
  /// **'无法读取所选文件。'**
  String get backupUnreadable;

  /// No description provided for @backupTransferBusy.
  ///
  /// In zh, this message translates to:
  /// **'已有备份任务正在进行。'**
  String get backupTransferBusy;

  /// No description provided for @backupImportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败，当前数据未被修改。'**
  String get backupImportFailed;

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

  /// No description provided for @appLock.
  ///
  /// In zh, this message translates to:
  /// **'系统解锁'**
  String get appLock;

  /// No description provided for @appLockDisabledDescription.
  ///
  /// In zh, this message translates to:
  /// **'使用指纹、人脸、虹膜或锁屏凭据保护日记'**
  String get appLockDisabledDescription;

  /// No description provided for @appLockEnabledDescription.
  ///
  /// In zh, this message translates to:
  /// **'每次打开或返回应用时需要验证'**
  String get appLockEnabledDescription;

  /// No description provided for @appLockEnableReason.
  ///
  /// In zh, this message translates to:
  /// **'验证身份以开启影迹的系统解锁'**
  String get appLockEnableReason;

  /// No description provided for @appLockDisableReason.
  ///
  /// In zh, this message translates to:
  /// **'验证身份以关闭影迹的系统解锁'**
  String get appLockDisableReason;

  /// No description provided for @appLockAuthenticateReason.
  ///
  /// In zh, this message translates to:
  /// **'解锁影迹以查看日记'**
  String get appLockAuthenticateReason;

  /// No description provided for @appLockLockedTitle.
  ///
  /// In zh, this message translates to:
  /// **'影迹已锁定'**
  String get appLockLockedTitle;

  /// No description provided for @appLockLockedDescription.
  ///
  /// In zh, this message translates to:
  /// **'请使用生物特征或 PIN、图案、密码继续'**
  String get appLockLockedDescription;

  /// No description provided for @appLockUnlock.
  ///
  /// In zh, this message translates to:
  /// **'解锁'**
  String get appLockUnlock;

  /// No description provided for @appLockAuthenticating.
  ///
  /// In zh, this message translates to:
  /// **'正在验证…'**
  String get appLockAuthenticating;

  /// No description provided for @appLockUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'请先在系统设置中配置生物特征、PIN、图案或密码。'**
  String get appLockUnavailable;

  /// No description provided for @appLockCanceled.
  ///
  /// In zh, this message translates to:
  /// **'未完成身份验证。'**
  String get appLockCanceled;

  /// No description provided for @appLockFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法验证身份，请重试。'**
  String get appLockFailed;

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

  /// No description provided for @editorLoadError.
  ///
  /// In zh, this message translates to:
  /// **'无法加载这一天的日记。'**
  String get editorLoadError;

  /// No description provided for @editorTitlePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'今天的标题'**
  String get editorTitlePlaceholder;

  /// No description provided for @editorBodyPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'写下今天发生的事……'**
  String get editorBodyPlaceholder;

  /// No description provided for @editorMood.
  ///
  /// In zh, this message translates to:
  /// **'心情'**
  String get editorMood;

  /// No description provided for @editorSaving.
  ///
  /// In zh, this message translates to:
  /// **'正在保存…'**
  String get editorSaving;

  /// No description provided for @editorSaved.
  ///
  /// In zh, this message translates to:
  /// **'已自动保存'**
  String get editorSaved;

  /// No description provided for @editorSaveError.
  ///
  /// In zh, this message translates to:
  /// **'保存失败，请重试。'**
  String get editorSaveError;

  /// No description provided for @editorCollapseDates.
  ///
  /// In zh, this message translates to:
  /// **'收起日期'**
  String get editorCollapseDates;

  /// No description provided for @editorExpandDates.
  ///
  /// In zh, this message translates to:
  /// **'展开日期'**
  String get editorExpandDates;

  /// No description provided for @editorMoodHappy.
  ///
  /// In zh, this message translates to:
  /// **'开心'**
  String get editorMoodHappy;

  /// No description provided for @editorMoodExcited.
  ///
  /// In zh, this message translates to:
  /// **'兴奋'**
  String get editorMoodExcited;

  /// No description provided for @editorMoodCalm.
  ///
  /// In zh, this message translates to:
  /// **'平静'**
  String get editorMoodCalm;

  /// No description provided for @editorMoodTired.
  ///
  /// In zh, this message translates to:
  /// **'疲惫'**
  String get editorMoodTired;

  /// No description provided for @editorMoodSad.
  ///
  /// In zh, this message translates to:
  /// **'难过'**
  String get editorMoodSad;

  /// No description provided for @editorAddImage.
  ///
  /// In zh, this message translates to:
  /// **'添加图片'**
  String get editorAddImage;

  /// No description provided for @editorImageAddError.
  ///
  /// In zh, this message translates to:
  /// **'添加图片失败。'**
  String get editorImageAddError;

  /// No description provided for @editorImageDiaryLimit.
  ///
  /// In zh, this message translates to:
  /// **'每篇日记最多添加 {maxImages} 张图片。'**
  String editorImageDiaryLimit(int maxImages);

  /// No description provided for @editorAdjustImageSize.
  ///
  /// In zh, this message translates to:
  /// **'调整图片大小'**
  String get editorAdjustImageSize;

  /// No description provided for @editorImageMissing.
  ///
  /// In zh, this message translates to:
  /// **'图片不可用'**
  String get editorImageMissing;

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
