import 'package:slipstream/core/models/stored_subscription/stored_subscription.dart';

abstract interface class SubscriptionStorage {
  Future<List<StoredSubscription>> loadAll();
  Future<void> save(StoredSubscription subscription);
  Future<void> delete(String subscriptionId);

  /// Whether [subscriptionId] is still stored. Lets a background refresh
  /// skip its save when the user deleted the subscription meanwhile.
  Future<bool> exists(String subscriptionId);
}
