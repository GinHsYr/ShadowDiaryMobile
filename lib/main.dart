import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/archives/archive_repository.dart';
import 'core/backup/backup_import_service.dart';
import 'core/backup/backup_export_service.dart';
import 'core/database/app_database.dart';
import 'core/diary/diary_repository.dart';
import 'core/settings/app_settings_controller.dart';
import 'core/settings/app_settings_repository.dart';
import 'core/services/diary_image_store.dart';
import 'core/services/archive_image_service.dart';
import 'core/services/diary_image_debug_trace.dart';
import 'core/sync/lan_discovery_service.dart';
import 'core/sync/sync_client.dart';
import 'core/sync/sync_controller.dart';
import 'core/sync/sync_repository.dart';
import 'core/sync/sync_secure_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DiaryImageDebugTrace.event('app.bootstrap.begin');

  try {
    final database = await AppDatabase.openBundled();
    final diaryImageStore = await DiaryImageStore.loadDefault();
    await diaryImageStore.migrateLegacyReferences(database);
    DiaryImageDebugTrace.appReady(
      imageDirectory: diaryImageStore.imageDirectory.path,
    );
    final settingsRepository = SqliteAppSettingsRepository(database);
    final diaryRepository = SqliteDiaryRepository(database);
    final archiveRepository = SqliteArchiveRepository(database);
    final diaryImageCleanup = DatabaseDiaryImageCleanup(
      diaryImageStore,
      database,
    );
    final archiveImageService = DeviceArchiveImageService(
      imageStore: diaryImageStore,
      isImageReferenced: (source) =>
          diaryImageStore.isReferenced(database, source),
    );
    final backupImportService = DeviceBackupImportService(
      database,
      imageStore: diaryImageStore,
    );
    final backupExportService = DeviceBackupExportService(
      database,
      imageStore: diaryImageStore,
    );
    final initialSettings = await settingsRepository.load();
    final syncSecureStore = DeviceSyncSecureStore();
    final syncDeviceId = await syncSecureStore.getOrCreateDeviceId();
    final syncRepository = SyncRepository(
      database,
      syncDeviceId,
      imageStore: diaryImageStore,
    );
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
          diaryImageStoreProvider.overrideWithValue(diaryImageStore),
          diaryImageCleanupProvider.overrideWithValue(diaryImageCleanup),
          archiveImageServiceProvider.overrideWithValue(archiveImageService),
          initialAppSettingsProvider.overrideWithValue(initialSettings),
          backupImportServiceProvider.overrideWithValue(backupImportService),
          backupExportServiceProvider.overrideWithValue(backupExportService),
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
    DiaryImageDebugTrace.error('app.bootstrap.failed', error);
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
