import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';

/// Coming back to the app after this long re-pings the whole list: latency
/// shown from an hour ago is no longer worth trusting, while a quick switch
/// to another app and back should not fire a burst of probes.
const repingOnResumeAfter = Duration(minutes: 10);

/// Subscriptions that were refreshed successfully between [previous] and
/// [next] — their servers may be new, and new servers have no ping yet.
/// A failed attempt does not move `lastUpdatedAt`, so it is not listed.
List<String> refreshedSubscriptionIds(
  SubscriptionsState previous,
  SubscriptionsState next,
) {
  final before = {
    for (final s in previous.subscriptions)
      s.subscription.id: s.subscription.lastUpdatedAt,
  };
  return [
    for (final s in next.subscriptions)
      if (before[s.subscription.id] case final at?
          when at != s.subscription.lastUpdatedAt)
        s.subscription.id,
  ];
}

bool shouldRepingOnResume(DateTime? lastFullRunAt, DateTime now) =>
    lastFullRunAt == null ||
    now.difference(lastFullRunAt) >= repingOnResumeAfter;
