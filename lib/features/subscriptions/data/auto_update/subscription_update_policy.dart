import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/auto_update_interval.dart';

/// How long to wait after a failed attempt before trying again. Short enough
/// to recover soon after the network or the panel comes back, long enough not
/// to hammer a panel that is down.
const failureRetryDelay = Duration(minutes: 30);

/// A subscription counts as due this much before its exact time, so a
/// periodic check (the hourly background job) never skips it by a few
/// seconds and leaves it for a whole extra period.
const dueTolerance = Duration(minutes: 5);

/// The interval [subscription] is auto-updated at, or null when it is not
/// auto-updated: no URL to fetch, or auto-update is [AutoUpdateInterval.off].
/// The provider's `profile-update-interval` wins over [setting].
Duration? effectiveUpdateInterval(
  Subscription subscription,
  AutoUpdateInterval setting,
) {
  final settingHours = setting.hours;
  if (subscription.url == null || settingHours == null) return null;
  final providerHours = subscription.updateIntervalHours;
  if (providerHours != null && providerHours > 0) {
    return Duration(hours: providerHours);
  }
  return Duration(hours: settingHours);
}

/// When [subscription] should be refreshed next, or null if never.
///
/// After a failed attempt it is retried [failureRetryDelay] later, but never
/// earlier than the normal schedule: a failed manual refresh must not bring
/// the next automatic one forward.
DateTime? nextUpdateAt(Subscription subscription, AutoUpdateInterval setting) {
  final interval = effectiveUpdateInterval(subscription, setting);
  if (interval == null) return null;
  final scheduled = subscription.lastUpdatedAt.add(interval);

  final attemptAt = subscription.lastAttemptAt;
  if (subscription.lastError == null || attemptAt == null) return scheduled;
  final retry = attemptAt.add(failureRetryDelay);
  return retry.isAfter(scheduled) ? retry : scheduled;
}

bool isUpdateDue(
  Subscription subscription,
  AutoUpdateInterval setting,
  DateTime now,
) {
  final next = nextUpdateAt(subscription, setting);
  return next != null && !now.isBefore(next.subtract(dueTolerance));
}

/// How long until the nearest of [subscriptions] is due: zero if one is
/// already overdue, null if none is auto-updated.
Duration? delayUntilNextUpdate(
  Iterable<Subscription> subscriptions,
  AutoUpdateInterval setting,
  DateTime now,
) {
  DateTime? nearest;
  for (final subscription in subscriptions) {
    final next = nextUpdateAt(subscription, setting);
    if (next != null && (nearest == null || next.isBefore(nearest))) {
      nearest = next;
    }
  }
  if (nearest == null) return null;
  final delay = nearest.difference(now);
  return delay.isNegative ? Duration.zero : delay;
}
