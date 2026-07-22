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
  String get archiveAdd => 'Add archive';

  @override
  String get archiveTypePerson => 'Person';

  @override
  String get archiveTypeOther => 'Other';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get retry => 'Retry';

  @override
  String get archiveDeleteTitle => 'Delete archive?';

  @override
  String archiveDeleteMessage(String name) {
    return 'Delete “$name”? This cannot be undone.';
  }

  @override
  String get archiveDeleteAction => 'Delete this archive';

  @override
  String get archiveDeleteError => 'Could not delete the archive. Try again.';

  @override
  String get archiveLoadError => 'Could not load archives. Try again.';

  @override
  String get archiveEditorNewTitle => 'Add archive';

  @override
  String get archiveEditorEditTitle => 'Edit archive';

  @override
  String get archiveSaving => 'Saving';

  @override
  String get archiveSaveError => 'Could not save the archive. Try again.';

  @override
  String get archiveMainImage => 'Main image';

  @override
  String get archiveChooseMainImage => 'Choose main image';

  @override
  String get archiveChangeMainImage => 'Change main image';

  @override
  String get archiveName => 'Name';

  @override
  String get archiveNameHint => 'Enter an archive name';

  @override
  String get archiveNameRequired => 'Enter an archive name';

  @override
  String get archiveAlias => 'Aliases';

  @override
  String get archiveAliasHint => 'Enter one alias';

  @override
  String get archiveAddAlias => 'Add alias';

  @override
  String get archiveAddAliasAction => 'Add';

  @override
  String get archiveRemoveAlias => 'Remove alias';

  @override
  String get archiveAliasDuplicate => 'This alias already exists';

  @override
  String get archiveType => 'Archive type';

  @override
  String get archiveDescription => 'Description';

  @override
  String get archiveDescriptionHint => 'Record information about this archive';

  @override
  String get archiveGallery => 'Gallery';

  @override
  String archiveImageCount(int count, int max) {
    return '$count / $max';
  }

  @override
  String get archiveAddImages => 'Add images';

  @override
  String get archiveRemoveImage => 'Remove image';

  @override
  String archiveImageLimit(int maxImages) {
    return 'An archive can contain up to $maxImages images, including its main image.';
  }

  @override
  String get archiveImageAddError => 'Could not add the images. Try again.';

  @override
  String get archiveImageMissing => 'Image unavailable';

  @override
  String archiveImagePosition(int index, int total) {
    return 'Image $index of $total';
  }

  @override
  String get archiveDiscardTitle => 'Discard changes?';

  @override
  String get archiveDiscardMessage =>
      'Unsaved changes and newly added images will be lost.';

  @override
  String get archiveContinueEditing => 'Keep editing';

  @override
  String get archiveDiscardAction => 'Discard changes';

  @override
  String get mediaEmptyTitle => 'No media yet';

  @override
  String get mediaEmptyBody =>
      'Images from diaries and archives will be collected here.';

  @override
  String mediaImageTotal(int count) {
    return '$count images';
  }

  @override
  String get mediaFilterAll => 'All';

  @override
  String get mediaFilterDiary => 'Diaries';

  @override
  String get mediaFilterArchive => 'Archives';

  @override
  String get mediaFilteredEmpty => 'No images in this category yet';

  @override
  String get mediaLoadError => 'Could not load media. Try again.';

  @override
  String get mediaImageMissing => 'Image unavailable';

  @override
  String get mediaUntitledDiary => 'Untitled diary';

  @override
  String get mediaViewSource => 'View source';

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
  String get settingsData => 'Data';

  @override
  String get settingsServices => 'Services';

  @override
  String get backupImport => 'Import backup';

  @override
  String get backupImportDescription =>
      'Restore diaries and archives from a ShadowDiary ZIP backup';

  @override
  String get backupReading => 'Reading backup...';

  @override
  String get backupPreviewTitle => 'Backup details';

  @override
  String get backupFileName => 'File';

  @override
  String get backupAppVersion => 'Exported by';

  @override
  String get backupExportedAt => 'Exported at';

  @override
  String get backupFormatVersion => 'Format version';

  @override
  String get backupDiaryCount => 'Diary entries';

  @override
  String get backupArchiveCount => 'Archives';

  @override
  String get backupAttachmentCount => 'Attachments';

  @override
  String get backupMediaCount => 'Media files';

  @override
  String get backupImportMode => 'Import mode';

  @override
  String get backupOverwrite => 'Overwrite';

  @override
  String get backupOverwriteDescription =>
      'Remove current diaries and archives, then restore this backup. Current app settings stay unchanged.';

  @override
  String get backupIncremental => 'Incremental';

  @override
  String get backupIncrementalDescription =>
      'Import only dates without a local diary, keeping current diaries, archives, and settings.';

  @override
  String get backupConflictCount => 'Conflicting diaries';

  @override
  String backupConflictDiaryCount(int count) {
    return '$count will not be imported';
  }

  @override
  String get backupStartImport => 'Start import';

  @override
  String get backupImporting => 'Importing backup...';

  @override
  String backupOverwriteSuccess(int diaryCount, int archiveCount) {
    return 'Imported $diaryCount diaries and $archiveCount archives.';
  }

  @override
  String backupIncrementalSuccess(int diaryCount, int skippedCount) {
    return 'Imported $diaryCount diaries and skipped $skippedCount conflicts.';
  }

  @override
  String get backupUnavailable =>
      'Backup import is not available on this device.';

  @override
  String get backupInvalid => 'This is not a valid ShadowDiary backup.';

  @override
  String get backupUnsupportedFormat =>
      'This backup format version is not supported.';

  @override
  String get backupMissingKey =>
      'The database key file is missing from the backup.';

  @override
  String get backupUnreadable => 'The selected file could not be read.';

  @override
  String get backupTransferBusy =>
      'Another backup operation is already running.';

  @override
  String get backupImportFailed =>
      'Import failed. Current data was not changed.';

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
  String get appLockDisableReason =>
      'Authenticate to turn off system unlock for ShadowDiary';

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
