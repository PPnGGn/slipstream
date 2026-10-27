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

ToastSpec subscriptionDeletedToast(String name) =>
    ToastSpec('Subscription deleted', subtitle: name.toUpperCase());
