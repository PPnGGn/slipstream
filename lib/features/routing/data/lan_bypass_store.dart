import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether traffic to the local network skips the VPN. On by default: the
/// private ranges always went direct before the switch existed, so an update
/// changes nothing by itself.
@lazySingleton
class LanBypassStore {
  static const _key = 'routing_lan_bypass';

  final SharedPreferences _prefs;

  LanBypassStore(this._prefs);

  bool load() => _prefs.getBool(_key) ?? true;

  Future<void> save({required bool enabled}) => _prefs.setBool(_key, enabled);
}
