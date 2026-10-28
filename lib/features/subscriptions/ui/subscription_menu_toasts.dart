import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/features/subscriptions/cubit/refresh_outcome.dart';
import 'package:slipstream/features/subscriptions/ui/add_subscription_toasts.dart';

// What the subscription's ⋯ menu says about its actions, as toasts.

/// The toast for a manual refresh; null when nothing happened (see
/// [RefreshIgnored]).
ToastSpec? refreshToast(RefreshOutcome outcome) => switch (outcome) {
  Refreshed(:final subscription) => ToastSpec(
    'Subscription updated',
    subtitle:
        '${subscription.servers.length} '
        '${subscription.servers.length == 1 ? 'SERVER' : 'SERVERS'} · '
        '${subscription.subscription.name.toUpperCase()}',
  ),
  RefreshFailed(:final cause) => subscriptionFailedToast(
    cause,
    fallbackTitle: "Couldn't update subscription",
  ),
  RefreshIgnored() => null,
};

/// The toast for the list's pull down, which refreshes every URL
/// subscription at once. One subscription reads like [refreshToast]; for
/// several it sums up, and each failed one is marked in its own header.
ToastSpec? refreshAllToast(List<RefreshOutcome> outcomes) {
  final done = outcomes.where((o) => o is! RefreshIgnored).toList();
  if (done.isEmpty) return null;
  if (done.length == 1) return refreshToast(done.single);

  final failed = done.whereType<RefreshFailed>().length;
  if (failed > 0) {
    return ToastSpec(
      "Couldn't update $failed of ${done.length}",
      subtitle: 'MARKED IN THE LIST',
      kind: ToastKind.error,
    );
  }
  final servers = done.whereType<Refreshed>().fold(
    0,
    (sum, r) => sum + r.subscription.servers.length,
  );
  return ToastSpec(
    'Subscriptions updated',
    subtitle: '${done.length} SUBSCRIPTIONS · $servers SERVERS',
  );
}

ToastSpec subscriptionDeletedToast(String name) =>
    ToastSpec('Subscription deleted', subtitle: name.toUpperCase());
