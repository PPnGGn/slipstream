import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@lazySingleton
class ThemeStore {
  static const _key = 'app_theme_mode';

  final SharedPreferences _prefs;

  ThemeStore(this._prefs);

  bool loadIsDark() => _prefs.getString(_key) == 'dark';

  Future<void> saveIsDark(bool isDark) =>
      _prefs.setString(_key, isDark ? 'dark' : 'light');
}
