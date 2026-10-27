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

    /// What went wrong with the last add, as an exception type: the add
    /// sheet picks its wording from this, [errorMessage] is the log line.
    Object? errorCause,

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
