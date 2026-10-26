import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_mode.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_settings.dart';

@lazySingleton
class SplitTunnelStore {
  static const _enabledKey = 'split_tunnel_enabled';
  static const _modeKey = 'split_tunnel_mode';
  static const _packagesKey = 'split_tunnel_packages';
  static const _includeSystemKey = 'split_tunnel_include_system';

  final SharedPreferences _prefs;

  SplitTunnelStore(this._prefs);

  SplitTunnelSettings load() => SplitTunnelSettings(
    enabled: _prefs.getBool(_enabledKey) ?? false,
    mode: SplitTunnelMode.fromName(_prefs.getString(_modeKey)),
    packages: (_prefs.getStringList(_packagesKey) ?? const []).toSet(),
    includeSystem: _prefs.getBool(_includeSystemKey) ?? false,
  );

  Future<void> save(SplitTunnelSettings settings) => Future.wait([
    _prefs.setBool(_enabledKey, settings.enabled),
    _prefs.setString(_modeKey, settings.mode.name),
    _prefs.setStringList(_packagesKey, settings.packages.toList()..sort()),
    _prefs.setBool(_includeSystemKey, settings.includeSystem),
  ]);
}
