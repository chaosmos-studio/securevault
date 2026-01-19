import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class MigrationService {
  static const _dataVersionKey = 'data_version';
  static const int currentDataVersion = 1;

  static Future<void> runMigrations() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(_dataVersionKey) ?? 0;

    if (storedVersion < currentDataVersion) {
      await _migrate(storedVersion, currentDataVersion, prefs);
      await prefs.setInt(_dataVersionKey, currentDataVersion);
    }
  }

  static Future<void> _migrate(int fromVersion, int toVersion, SharedPreferences prefs) async {
    for (int version = fromVersion; version < toVersion; version++) {
      switch (version) {
        case 0:
          await _migrateFromV0ToV1(prefs);
          break;
      }
    }
  }

  static Future<void> _migrateFromV0ToV1(SharedPreferences prefs) async {
    if (!prefs.containsKey('auto_lock_seconds')) {
      await prefs.setInt('auto_lock_seconds', AppConstants.autoLockSeconds);
    }
  }
}
