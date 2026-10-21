import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/appearance/data/home_layout.dart';

@lazySingleton
class HomeLayoutStore {
  static const _key = 'home_layout';

  final SharedPreferences _prefs;

  HomeLayoutStore(this._prefs);

  /// Classic on a fresh install.
  HomeLayout load() => HomeLayout.fromName(_prefs.getString(_key));

  Future<void> save(HomeLayout layout) => _prefs.setString(_key, layout.name);
}
