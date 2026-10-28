import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the order of the subscription cards (their ids, top to bottom).
/// The subscriptions themselves are separate files with no order of their own.
@lazySingleton
class SubscriptionOrderStore {
  static const _key = 'subscription_order';

  final SharedPreferences _prefs;

  SubscriptionOrderStore(this._prefs);

  List<String> load() => _prefs.getStringList(_key) ?? const [];

  Future<void> save(List<String> ids) => _prefs.setStringList(_key, ids);
}
