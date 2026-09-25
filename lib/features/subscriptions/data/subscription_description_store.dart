import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists which subscriptions have their announce/description text
/// shown in the always-visible info block. Hidden by default — the
/// menu's "Show description" is an opt-in per subscription.
@lazySingleton
class SubscriptionDescriptionStore {
  static const _key = 'subscription_description_shown_ids';

  final SharedPreferences _prefs;

  SubscriptionDescriptionStore(this._prefs);

  bool isShown(String subscriptionId) =>
      (_prefs.getStringList(_key) ?? const []).contains(subscriptionId);

  Future<void> setShown(String subscriptionId, bool shown) async {
    final ids = {...(_prefs.getStringList(_key) ?? const [])};
    if (shown) {
      ids.add(subscriptionId);
    } else {
      ids.remove(subscriptionId);
    }
    await _prefs.setStringList(_key, ids.toList());
  }
}
