import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the latency value is shown in the server list.
enum PingDisplayMode { dots, numbers }

/// Persisted ping feature settings (see the spec's "Настройки" item).
@lazySingleton
class PingSettingsStore {
  static const _displayModeKey = 'ping_display_mode';
  static const _pingOnAppStartKey = 'ping_on_app_start';
  static const _sortByPingKey = 'ping_sort_by_ping';

  final SharedPreferences _prefs;

  PingSettingsStore(this._prefs);

  /// Numbers (the design's value pill) by default — dots is the
  /// compact opt-in, not the primary look (spec update).
  PingDisplayMode loadDisplayMode() {
    final stored = _prefs.getString(_displayModeKey);
    return stored == PingDisplayMode.dots.name
        ? PingDisplayMode.dots
        : PingDisplayMode.numbers;
  }

  Future<void> saveDisplayMode(PingDisplayMode mode) =>
      _prefs.setString(_displayModeKey, mode.name);

  /// On by default: the spec lists app start as one of three triggers.
  bool loadPingOnAppStart() => _prefs.getBool(_pingOnAppStartKey) ?? true;

  Future<void> savePingOnAppStart(bool enabled) =>
      _prefs.setBool(_pingOnAppStartKey, enabled);

  /// On by default, per the spec's sorting section.
  bool loadSortByPing() => _prefs.getBool(_sortByPingKey) ?? true;

  Future<void> saveSortByPing(bool enabled) =>
      _prefs.setBool(_sortByPingKey, enabled);
}
