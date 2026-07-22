import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/archives/archive_repository.dart';
import 'core/database/app_database.dart';
import 'core/diary/diary_repository.dart';
import 'core/settings/app_settings_controller.dart';
import 'core/settings/app_settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final database = await AppDatabase.openBundled();
    final settingsRepository = SqliteAppSettingsRepository(database);
    final diaryRepository = SqliteDiaryRepository(database);
    final archiveRepository = SqliteArchiveRepository(database);
    final initialSettings = await settingsRepository.load();

    runApp(
      ProviderScope(
        overrides: [
          appSettingsRepositoryProvider.overrideWithValue(settingsRepository),
          initialAppSettingsProvider.overrideWithValue(initialSettings),
          diaryRepositoryProvider.overrideWithValue(diaryRepository),
          archiveRepositoryProvider.overrideWithValue(archiveRepository),
        ],
        child: const ShadowDiaryApp(),
      ),
    );
  } on Object catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'ShadowDiary bootstrap',
      ),
    );
    runApp(const BootstrapFailureApp());
  }
}
