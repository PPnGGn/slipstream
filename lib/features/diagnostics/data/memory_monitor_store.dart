import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/diagnostics/data/memory_monitor_mode.dart';

@lazySingleton
class MemoryMonitorStore {
  static const _key = 'memory_monitor_mode';

  final SharedPreferences _prefs;

  MemoryMonitorStore(this._prefs);

  /// Off by default on a fresh install.
  MemoryMonitorMode load() => MemoryMonitorMode.fromName(_prefs.getString(_key));

  Future<void> save(MemoryMonitorMode mode) =>
      _prefs.setString(_key, mode.name);
}
