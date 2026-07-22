// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'ShadowDiary';

  @override
  String get navigationHome => 'Home';

  @override
  String get navigationArchives => 'Archives';

  @override
  String get navigationMedia => 'Media';

  @override
  String get navigationSettings => 'Settings';

  @override
  String get newDiary => 'New diary';

  @override
  String get homeGreeting => 'Hello, ready to write?';

  @override
  String get homeEmptyTitle => 'Start with today';

  @override
  String get homeEmptyBody =>
      'Calendar, insights, and recent entries will arrive in a later feature phase.';

  @override
  String get homeStatisticsDiaryLabel => 'You wrote';

  @override
  String get homeStatisticsDiaryUnit => 'entries';

  @override
  String get homeStatisticsStreakLabel => 'Streak';

  @override
  String get homeStatisticsStreakUnit => 'days';

  @override
  String get homeStatisticsCharacterLabel => 'Total';

  @override
  String get homeStatisticsCharacterUnit => 'characters';

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarYesterday => 'Yesterday';

  @override
  String get calendarLastWeekSameDay => 'This day last week';

  @override
  String get calendarLastMonthSameDay => 'This day last month';

  @override
  String get calendarHasDiary => 'Diary entry';

  @override
  String get calendarMonthlyProgress => 'Monthly writing progress';

  @override
  String get calendarSelectMonth => 'Select year and month';

  @override
  String get calendarYear => 'Year';

  @override
  String get calendarMonth => 'Month';

  @override
  String calendarWrittenDays(int writtenDays, int totalDays) {
    return 'Written $writtenDays / $totalDays days';
  }

  @override
  String get archivesEmptyTitle => 'No archives yet';

  @override
  String get archivesEmptyBody =>
      'People and other archives will be organized here.';

  @override
  String get mediaEmptyTitle => 'No media yet';

  @override
  String get mediaEmptyBody =>
      'Images from diaries and archives will be collected here.';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsThemeMode => 'Display mode';

  @override
  String get settingsThemeColor => 'Theme color';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsServices => 'Services';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get colorNeutral => 'Neutral';

  @override
  String get colorIndigo => 'Indigo';

  @override
  String get colorTeal => 'Teal';

  @override
  String get colorRose => 'Rose';

  @override
  String get colorMonet => 'Monet dynamic color';

  @override
  String get languageSystem => 'System';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get biometricLock => 'Biometric lock';

  @override
  String get appLock => 'System unlock';

  @override
  String get appLockDisabledDescription =>
      'Protect diaries with biometrics or your screen lock';

  @override
  String get appLockEnabledDescription =>
      'Authenticate whenever you open or return to the app';

  @override
  String get appLockEnableReason =>
      'Authenticate to turn on system unlock for ShadowDiary';

  @override
  String get appLockAuthenticateReason =>
      'Unlock ShadowDiary to view your diaries';

  @override
  String get appLockLockedTitle => 'ShadowDiary is locked';

  @override
  String get appLockLockedDescription =>
      'Use biometrics, a PIN, pattern, or password to continue';

  @override
  String get appLockUnlock => 'Unlock';

  @override
  String get appLockAuthenticating => 'Authenticating…';

  @override
  String get appLockUnavailable =>
      'Set up biometrics, a PIN, pattern, or password in system settings first.';

  @override
  String get appLockCanceled => 'Authentication was not completed.';

  @override
  String get appLockFailed => 'Could not authenticate. Try again.';

  @override
  String get lanSync => 'LAN sync';

  @override
  String get notConfigured => 'Not configured';

  @override
  String get editorNewTitle => 'New diary';

  @override
  String get editorEditTitle => 'Edit diary';

  @override
  String get editorPlaceholder =>
      'The rich-text editor will be connected in a later feature phase.';

  @override
  String get editorLoadError => 'This diary could not be loaded.';

  @override
  String get editorTitlePlaceholder => 'Today\'s title';

  @override
  String get editorBodyPlaceholder => 'Write what happened today...';

  @override
  String get editorMood => 'Mood';

  @override
  String get editorSaving => 'Saving...';

  @override
  String get editorSaved => 'Auto-saved';

  @override
  String get editorSaveError => 'Could not save. Please try again.';

  @override
  String get editorCollapseDates => 'Collapse dates';

  @override
  String get editorExpandDates => 'Expand dates';

  @override
  String get editorMoodHappy => 'Happy';

  @override
  String get editorMoodExcited => 'Excited';

  @override
  String get editorMoodCalm => 'Calm';

  @override
  String get editorMoodTired => 'Tired';

  @override
  String get editorMoodSad => 'Sad';

  @override
  String get editorAddImage => 'Add image';

  @override
  String get editorImageAddError => 'Could not add the image.';

  @override
  String editorImageDiaryLimit(int maxImages) {
    return 'A diary can contain up to $maxImages images.';
  }

  @override
  String get editorAdjustImageSize => 'Adjust image size';

  @override
  String get editorImageMissing => 'Image unavailable';

  @override
  String get bootstrapFailed => 'ShadowDiary could not start';

  @override
  String get bootstrapFailedHint =>
      'The local database could not be initialized. Restart the app to try again.';
}
