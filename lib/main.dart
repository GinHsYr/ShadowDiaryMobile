import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/archives/archive_repository.dart';
import 'core/backup/backup_import_service.dart';
import 'core/database/app_database.dart';
import 'core/diary/diary_repository.dart';
import 'core/settings/app_settings_controller.dart';
import 'core/settings/app_settings_repository.dart';
import 'core/sync/lan_discovery_service.dart';
import 'core/sync/sync_client.dart';
import 'core/sync/sync_controller.dart';
import 'core/sync/sync_repository.dart';
import 'core/sync/sync_secure_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final database = await AppDatabase.openBundled();
    final settingsRepository = SqliteAppSettingsRepository(database);
    final diaryRepository = SqliteDiaryRepository(database);
    final archiveRepository = SqliteArchiveRepository(database);
    final backupImportService = DeviceBackupImportService(database);
    final initialSettings = await settingsRepository.load();
    final syncSecureStore = DeviceSyncSecureStore();
    final syncDeviceId = await syncSecureStore.getOrCreateDeviceId();
    final syncRepository = SyncRepository(database, syncDeviceId);
    final syncDiscoveryService = BonsoirSyncDiscoveryService();
    final syncClient = ShadowSyncClient(
      deviceId: syncDeviceId,
      repository: syncRepository,
      secureStore: syncSecureStore,
    );

    runApp(
      ProviderScope(
        overrides: [
          appSettingsRepositoryProvider.overrideWithValue(settingsRepository),
          initialAppSettingsProvider.overrideWithValue(initialSettings),
          backupImportServiceProvider.overrideWithValue(backupImportService),
          diaryRepositoryProvider.overrideWithValue(diaryRepository),
          archiveRepositoryProvider.overrideWithValue(archiveRepository),
          syncSecureStoreProvider.overrideWithValue(syncSecureStore),
          syncRepositoryProvider.overrideWithValue(syncRepository),
          syncDiscoveryServiceProvider.overrideWithValue(syncDiscoveryService),
          syncClientProvider.overrideWithValue(syncClient),
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
