part of 'subscriptions_cubit.dart';

@freezed
abstract class SubscriptionsState with _$SubscriptionsState {
  const factory SubscriptionsState({
    @Default(<StoredSubscription>[]) List<StoredSubscription> subscriptions,
    String? selectedSubscriptionId,
    String? selectedServerId,
    @Default(false) bool isAdding,
    @Default(<String>{}) Set<String> refreshingIds,
    String? errorMessage,

    /// False until the first read from storage lands: an empty list before
    /// that means "not known yet", not "no subscriptions".
    @Default(false) bool isLoaded,
  }) = _SubscriptionsState;

  const SubscriptionsState._();

  VpnServer? get selectedServer {
    for (final stored in subscriptions) {
      if (stored.subscription.id != selectedSubscriptionId) continue;
      for (final server in stored.servers) {
        if (server.id == selectedServerId) return server;
      }
    }
    return null;
  }
}
