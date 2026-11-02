import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether a failed start leaves the phone without internet instead of
/// without the VPN. On by default: a tunnel that fails must not leak traffic.
@lazySingleton
class KillSwitchStore {
  static const _key = 'kill_switch';

  final SharedPreferences _prefs;

  KillSwitchStore(this._prefs);

  bool load() => _prefs.getBool(_key) ?? true;

  Future<void> save({required bool enabled}) => _prefs.setBool(_key, enabled);
}
