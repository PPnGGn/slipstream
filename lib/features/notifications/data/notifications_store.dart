import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/notifications/data/notification_prefs.dart';

/// The alert switches in SharedPreferences, one key each. Missing reads as on,
/// so an install from before an alert existed gets it.
@lazySingleton
class NotificationsStore {
  static const _trafficBlockedKey = 'notify_traffic_blocked';
  static const _startFailedKey = 'notify_start_failed';
  static const _revokedKey = 'notify_revoked';
  static const _subscriptionFailedKey = 'notify_subscription_failed';

  final SharedPreferences _prefs;

  NotificationsStore(this._prefs);

  NotificationPrefs load() => NotificationPrefs(
    trafficBlocked: _prefs.getBool(_trafficBlockedKey) ?? true,
    startFailed: _prefs.getBool(_startFailedKey) ?? true,
    revoked: _prefs.getBool(_revokedKey) ?? true,
    subscriptionFailed: _prefs.getBool(_subscriptionFailedKey) ?? true,
  );

  Future<void> save(NotificationPrefs prefs) async {
    await _prefs.setBool(_trafficBlockedKey, prefs.trafficBlocked);
    await _prefs.setBool(_startFailedKey, prefs.startFailed);
    await _prefs.setBool(_revokedKey, prefs.revoked);
    await _prefs.setBool(_subscriptionFailedKey, prefs.subscriptionFailed);
  }
}
