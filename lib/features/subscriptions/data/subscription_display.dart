import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/core/utils/formatters.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/auto_update_interval.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/subscription_update_policy.dart';

/// What the line under a subscription's name shows, as data: the widget turns
/// it into icons (↻ 12h · 29.10.26, 01:11 · 40 ▤) and decides what to cut on
/// a narrow screen.
class SubscriptionMeta {
  const SubscriptionMeta({
    required this.updated,
    required this.serverCount,
    required this.interval,
    required this.failed,
    required this.refreshing,
  });

  final String updated;
  final int serverCount;
  final String? interval;
  final bool failed;
  final bool refreshing;
}

/// The interval is the one auto-update actually uses (the provider's, else
/// [autoUpdate]).
SubscriptionMeta subscriptionMeta(
  Subscription subscription, {
  required int serverCount,
  required bool refreshing,
  required AutoUpdateInterval autoUpdate,
}) {
  final interval = effectiveUpdateInterval(subscription, autoUpdate);
  return SubscriptionMeta(
    updated: formatUpdatedAtShort(subscription.lastUpdatedAt),
    serverCount: serverCount,
    interval: subscription.url == null
        ? null
        : interval == null
        ? 'off'
        : '${interval.inHours}h',
    failed: subscription.lastError != null,
    refreshing: refreshing,
  );
}
