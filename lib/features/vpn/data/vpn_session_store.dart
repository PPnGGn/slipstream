import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';

@lazySingleton
class VpnSessionStore {
  static const _key = 'last_connected_server';
  final SharedPreferences _prefs;
  VpnSessionStore(this._prefs);

  VpnServer? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return VpnServer.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(VpnServer server) =>
      _prefs.setString(_key, jsonEncode(server.toJson()));
}
