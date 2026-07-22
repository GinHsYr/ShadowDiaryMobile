// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '影迹';

  @override
  String get navigationHome => '首页';

  @override
  String get navigationArchives => '档案';

  @override
  String get navigationMedia => '媒体';

  @override
  String get navigationSettings => '设置';

  @override
  String get newDiary => '新建日记';

  @override
  String get homeGreeting => '你好，准备写点什么？';

  @override
  String get homeEmptyTitle => '从今天开始记录';

  @override
  String get homeEmptyBody => '日历、统计和最近日记将在后续功能阶段加入。';

  @override
  String get homeStatisticsDiaryLabel => '你一共写了';

  @override
  String get homeStatisticsDiaryUnit => '篇日记';

  @override
  String get homeStatisticsStreakLabel => '连续记录';

  @override
  String get homeStatisticsStreakUnit => '天';

  @override
  String get homeStatisticsCharacterLabel => '共写了';

  @override
  String get homeStatisticsCharacterUnit => '字';

  @override
  String get calendarToday => '今天';

  @override
  String get calendarYesterday => '昨天';

  @override
  String get calendarLastWeekSameDay => '上周今日';

  @override
  String get calendarLastMonthSameDay => '上月今日';

  @override
  String get calendarHasDiary => '有日记';

  @override
  String get calendarMonthlyProgress => '本月写作完成度';

  @override
  String get calendarSelectMonth => '选择年月';

  @override
  String get calendarYear => '年份';

  @override
  String get calendarMonth => '月份';

  @override
  String calendarWrittenDays(int writtenDays, int totalDays) {
    return '已写 $writtenDays / $totalDays 天';
  }

  @override
  String get archivesEmptyTitle => '还没有档案';

  @override
  String get archivesEmptyBody => '人物与其他档案会在这里集中整理。';

  @override
  String get mediaEmptyTitle => '还没有媒体';

  @override
  String get mediaEmptyBody => '日记和档案中的图片会汇集到这里。';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsThemeMode => '显示模式';

  @override
  String get settingsThemeColor => '主题色';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsSecurity => '安全';

  @override
  String get settingsServices => '服务';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get colorNeutral => '中性黑';

  @override
  String get colorIndigo => '靛蓝';

  @override
  String get colorTeal => '青绿';

  @override
  String get colorRose => '玫红';

  @override
  String get colorMonet => '莫奈取色';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get biometricLock => '生物识别锁';

  @override
  String get appLock => '系统解锁';

  @override
  String get appLockDisabledDescription => '使用指纹、人脸、虹膜或锁屏凭据保护日记';

  @override
  String get appLockEnabledDescription => '每次打开或返回应用时需要验证';

  @override
  String get appLockEnableReason => '验证身份以开启影迹的系统解锁';

  @override
  String get appLockDisableReason => '验证身份以关闭影迹的系统解锁';

  @override
  String get appLockAuthenticateReason => '解锁影迹以查看日记';

  @override
  String get appLockLockedTitle => '影迹已锁定';

  @override
  String get appLockLockedDescription => '请使用生物特征或 PIN、图案、密码继续';

  @override
  String get appLockUnlock => '解锁';

  @override
  String get appLockAuthenticating => '正在验证…';

  @override
  String get appLockUnavailable => '请先在系统设置中配置生物特征、PIN、图案或密码。';

  @override
  String get appLockCanceled => '未完成身份验证。';

  @override
  String get appLockFailed => '无法验证身份，请重试。';

  @override
  String get lanSync => '局域网同步';

  @override
  String get notConfigured => '尚未配置';

  @override
  String get editorNewTitle => '新建日记';

  @override
  String get editorEditTitle => '编辑日记';

  @override
  String get editorPlaceholder => '富文本编辑器将在后续功能阶段接入。';

  @override
  String get editorLoadError => '无法加载这一天的日记。';

  @override
  String get editorTitlePlaceholder => '今天的标题';

  @override
  String get editorBodyPlaceholder => '写下今天发生的事……';

  @override
  String get editorMood => '心情';

  @override
  String get editorSaving => '正在保存…';

  @override
  String get editorSaved => '已自动保存';

  @override
  String get editorSaveError => '保存失败，请重试。';

  @override
  String get editorCollapseDates => '收起日期';

  @override
  String get editorExpandDates => '展开日期';

  @override
  String get editorMoodHappy => '开心';

  @override
  String get editorMoodExcited => '兴奋';

  @override
  String get editorMoodCalm => '平静';

  @override
  String get editorMoodTired => '疲惫';

  @override
  String get editorMoodSad => '难过';

  @override
  String get editorAddImage => '添加图片';

  @override
  String get editorImageAddError => '添加图片失败。';

  @override
  String editorImageDiaryLimit(int maxImages) {
    return '每篇日记最多添加 $maxImages 张图片。';
  }

  @override
  String get editorAdjustImageSize => '调整图片大小';

  @override
  String get editorImageMissing => '图片不可用';

  @override
  String get bootstrapFailed => '影迹启动失败';

  @override
  String get bootstrapFailedHint => '无法初始化本地数据库，请重新启动应用。';
}
