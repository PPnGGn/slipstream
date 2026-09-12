import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';

@lazySingleton
class RuBypassStore {
  static const _key = 'ru_bypass_mode';

  final SharedPreferences _prefs;

  RuBypassStore(this._prefs);

  /// Defaults to [RuBypassMode.bypassRu] on a fresh install.
  RuBypassMode load() => RuBypassMode.fromName(_prefs.getString(_key));

  Future<void> save(RuBypassMode mode) => _prefs.setString(_key, mode.name);
}
