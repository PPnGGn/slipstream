import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the app connects to the selected server by itself when it opens.
/// Off by default: a VPN that starts without being asked is a surprise.
@lazySingleton
class AutoConnectStore {
  static const _key = 'auto_connect_on_launch';

  final SharedPreferences _prefs;

  AutoConnectStore(this._prefs);

  bool load() => _prefs.getBool(_key) ?? false;

  Future<void> save({required bool enabled}) => _prefs.setBool(_key, enabled);
}
