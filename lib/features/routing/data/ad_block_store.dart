import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/routing/data/ad_block_mode.dart';

@lazySingleton
class AdBlockStore {
  static const _key = 'ad_block_mode';
  static const _legacyBoolKey = 'ad_block_enabled';

  final SharedPreferences _prefs;

  AdBlockStore(this._prefs);

  /// Off by default. Migrates the old boolean flag: an install that had
  /// ad-block on (`category-ads-all`) keeps the [AdBlockMode.full] behaviour.
  AdBlockMode load() {
    final stored = _prefs.getString(_key);
    if (stored != null) return AdBlockMode.fromName(stored);

    final legacy = _prefs.getBool(_legacyBoolKey);
    if (legacy == true) return AdBlockMode.full;
    return AdBlockMode.off;
  }

  Future<void> save(AdBlockMode mode) => _prefs.setString(_key, mode.name);
}
