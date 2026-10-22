import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/auto_update_interval.dart';

/// Persisted subscription auto-update setting.
@lazySingleton
class SubscriptionUpdateSettingsStore {
  static const _intervalKey = 'subscription_auto_update';

  final SharedPreferences _prefs;

  SubscriptionUpdateSettingsStore(this._prefs);

  /// Every 12 hours by default: a common provider interval, and rare enough
  /// not to wake the radio for nothing.
  AutoUpdateInterval loadInterval() {
    final stored = _prefs.getString(_intervalKey);
    return AutoUpdateInterval.values.firstWhere(
      (i) => i.name == stored,
      orElse: () => AutoUpdateInterval.h12,
    );
  }

  Future<void> saveInterval(AutoUpdateInterval interval) =>
      _prefs.setString(_intervalKey, interval.name);
}
