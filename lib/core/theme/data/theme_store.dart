import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/core/theme/data/app_theme_mode.dart';

@lazySingleton
class ThemeStore {
  static const _key = 'app_theme_mode';

  final SharedPreferences _prefs;

  ThemeStore(this._prefs);

  AppThemeMode loadMode() => switch (_prefs.getString(_key)) {
    'dark' => AppThemeMode.dark,
    'system' => AppThemeMode.system,
    _ => AppThemeMode.light,
  };

  Future<void> saveMode(AppThemeMode mode) => _prefs.setString(_key, mode.name);
}
