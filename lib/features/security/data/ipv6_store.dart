import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the tunnel carries IPv6. Off by default: the app then adds no IPv6
/// address or route to the VPN, so Android blocks IPv6 and apps use IPv4.
@lazySingleton
class Ipv6Store {
  static const _key = 'tunnel_ipv6';

  final SharedPreferences _prefs;

  Ipv6Store(this._prefs);

  bool load() => _prefs.getBool(_key) ?? false;

  Future<void> save({required bool enabled}) => _prefs.setBool(_key, enabled);
}
