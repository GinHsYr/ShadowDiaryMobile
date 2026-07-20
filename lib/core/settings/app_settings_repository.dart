import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'app_settings.dart';

abstract interface class AppSettingsRepository {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}

class SqliteAppSettingsRepository implements AppSettingsRepository {
  SqliteAppSettingsRepository(this._appDatabase);

  static const _themeModeKey = 'appearance.theme_mode';
  static const _themeSeedKey = 'appearance.seed_color';
  static const _localeKey = 'appearance.locale';

  final AppDatabase _appDatabase;

  @override
  Future<AppSettings> load() async {
    final rows = await _appDatabase.database.query('settings');
    final values = <String, String>{
      for (final row in rows) row['key']! as String: row['value']! as String,
    };
    return AppSettings(
      themeMode: _enumValue(
        AppThemeMode.values,
        values[_themeModeKey],
        AppThemeMode.system,
      ),
      themeSeed: _enumValue(
        ThemeSeed.values,
        values[_themeSeedKey],
        ThemeSeed.neutral,
      ),
      localePreference: _enumValue(
        AppLocalePreference.values,
        values[_localeKey],
        AppLocalePreference.system,
      ),
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _appDatabase.database.transaction((transaction) async {
      final batch = transaction.batch();
      _upsert(batch, _themeModeKey, settings.themeMode.name);
      _upsert(batch, _themeSeedKey, settings.themeSeed.name);
      _upsert(batch, _localeKey, settings.localePreference.name);
      await batch.commit(noResult: true);
    });
  }

  void _upsert(Batch batch, String key, String value) {
    batch.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  T _enumValue<T extends Enum>(List<T> values, String? raw, T fallback) {
    for (final value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    return fallback;
  }
}
