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
  String get archiveAdd => '添加档案';

  @override
  String get archiveTypePerson => '人物';

  @override
  String get archiveTypeOther => '其他';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get retry => '重试';

  @override
  String get archiveDeleteTitle => '删除档案？';

  @override
  String archiveDeleteMessage(String name) {
    return '确定删除“$name”吗？此操作无法撤销。';
  }

  @override
  String get archiveDeleteAction => '删除这个档案';

  @override
  String get archiveDeleteError => '无法删除档案，请重试。';

  @override
  String get archiveLoadError => '无法加载档案，请重试。';

  @override
  String get archiveEditorNewTitle => '添加档案';

  @override
  String get archiveEditorEditTitle => '编辑档案';

  @override
  String get archiveSaving => '保存中';

  @override
  String get archiveSaveError => '无法保存档案，请重试。';

  @override
  String get archiveMainImage => '主图';

  @override
  String get archiveChooseMainImage => '选择主图';

  @override
  String get archiveChangeMainImage => '更换主图';

  @override
  String get archiveName => '名称';

  @override
  String get archiveNameHint => '输入档案名称';

  @override
  String get archiveNameRequired => '请输入档案名称';

  @override
  String get archiveAlias => '别名';

  @override
  String get archiveAliasHint => '输入一个别名';

  @override
  String get archiveAddAlias => '添加别名';

  @override
  String get archiveAddAliasAction => '添加';

  @override
  String get archiveRemoveAlias => '移除别名';

  @override
  String get archiveAliasDuplicate => '这个别名已经存在';

  @override
  String get archiveType => '档案类型';

  @override
  String get archiveDescription => '描述';

  @override
  String get archiveDescriptionHint => '记录与这个档案有关的信息';

  @override
  String get archiveGallery => '图库';

  @override
  String archiveImageCount(int count, int max) {
    return '$count / $max';
  }

  @override
  String get archiveAddImages => '添加图片';

  @override
  String get archiveRemoveImage => '移除图片';

  @override
  String archiveImageLimit(int maxImages) {
    return '每个档案最多保存 $maxImages 张图片（含主图）。';
  }

  @override
  String get archiveImageAddError => '添加图片失败，请重试。';

  @override
  String get archiveImageMissing => '图片不可用';

  @override
  String archiveImagePosition(int index, int total) {
    return '第 $index 张，共 $total 张';
  }

  @override
  String get archiveDiscardTitle => '放弃修改？';

  @override
  String get archiveDiscardMessage => '尚未保存的修改和新添加的图片将会丢失。';

  @override
  String get archiveContinueEditing => '继续编辑';

  @override
  String get archiveDiscardAction => '放弃修改';

  @override
  String get mediaEmptyTitle => '还没有媒体';

  @override
  String get mediaEmptyBody => '日记和档案中的图片会汇集到这里。';

  @override
  String mediaImageTotal(int count) {
    return '共 $count 张图片';
  }

  @override
  String get mediaFilterAll => '全部';

  @override
  String get mediaFilterDiary => '日记';

  @override
  String get mediaFilterArchive => '档案';

  @override
  String get mediaFilteredEmpty => '这个分类中还没有图片';

  @override
  String get mediaLoadError => '无法加载媒体，请重试。';

  @override
  String get mediaImageMissing => '图片不可用';

  @override
  String get mediaUntitledDiary => '未命名日记';

  @override
  String get mediaViewSource => '查看出处';

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
  String get settingsData => '数据';

  @override
  String get settingsServices => '服务';

  @override
  String get backupImport => '导入备份';

  @override
  String get backupImportDescription => '从 ShadowDiary ZIP 备份恢复日记和档案';

  @override
  String get backupReading => '正在读取备份…';

  @override
  String get backupPreviewTitle => '备份信息';

  @override
  String get backupFileName => '文件';

  @override
  String get backupAppVersion => '导出版本';

  @override
  String get backupExportedAt => '导出时间';

  @override
  String get backupFormatVersion => '格式版本';

  @override
  String get backupDiaryCount => '日记篇数';

  @override
  String get backupArchiveCount => '档案数';

  @override
  String get backupAttachmentCount => '附件数';

  @override
  String get backupMediaCount => '媒体文件数';

  @override
  String get backupImportMode => '导入方式';

  @override
  String get backupOverwrite => '覆盖导入';

  @override
  String get backupOverwriteDescription => '清除当前日记和档案，再恢复这份备份。当前应用设置不会改变。';

  @override
  String get backupIncremental => '增量导入';

  @override
  String get backupIncrementalDescription => '只导入本机尚未写过日记的日期，保留现有日记、档案和设置。';

  @override
  String get backupConflictCount => '冲突日记';

  @override
  String backupConflictDiaryCount(int count) {
    return '$count 篇不会导入';
  }

  @override
  String get backupStartImport => '开始导入';

  @override
  String get backupImporting => '正在导入备份…';

  @override
  String backupOverwriteSuccess(int diaryCount, int archiveCount) {
    return '已导入 $diaryCount 篇日记和 $archiveCount 个档案。';
  }

  @override
  String backupIncrementalSuccess(int diaryCount, int skippedCount) {
    return '已导入 $diaryCount 篇日记，跳过 $skippedCount 篇冲突日记。';
  }

  @override
  String get backupUnavailable => '此设备暂不支持导入备份。';

  @override
  String get backupInvalid => '这不是有效的 ShadowDiary 备份文件。';

  @override
  String get backupUnsupportedFormat => '此备份格式版本不受支持。';

  @override
  String get backupMissingKey => '备份中缺少数据库密钥文件。';

  @override
  String get backupUnreadable => '无法读取所选文件。';

  @override
  String get backupTransferBusy => '已有备份任务正在进行。';

  @override
  String get backupImportFailed => '导入失败，当前数据未被修改。';

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
