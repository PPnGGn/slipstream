import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/features/notifications/data/app_alerts.dart';

/// "Expires within this many days" is worth an alert; further off is not.
const expiringWithinDays = 3;

/// From this share of the limit the traffic is "running out".
const trafficLowPercent = 90;

/// The four things said about a subscription's time and traffic. [key] is what
/// `Subscription.notifiedAlerts` stores; the order is the order of the alerts.
enum _Limit {
  expiring('expiring', AppAlertKind.subscriptionExpiring),
  expired('expired', AppAlertKind.subscriptionExpired),
  trafficLow('trafficLow', AppAlertKind.trafficLow),
  trafficExhausted('trafficExhausted', AppAlertKind.trafficExhausted);

  const _Limit(this.key, this.kind);

  final String key;
  final AppAlertKind kind;
}

typedef LimitAlertToShow = ({AppAlertKind kind, int? number});

/// What to do about a subscription's alerts right now.
class LimitAlertPlan {
  const LimitAlertPlan({
    required this.show,
    required this.cancel,
    required this.notified,
  });

  /// Alerts to raise, in order.
  final List<LimitAlertToShow> show;

  /// Kinds whose alert is out of date and must be taken away.
  final List<AppAlertKind> cancel;

  /// The new `Subscription.notifiedAlerts`.
  final List<String> notified;
}

/// Decides, from the subscription as it is at [now], what to say about its time
/// and its traffic. Pure: the caller raises, takes back and stores.
///
/// What holds now ("active") comes from the figures alone: it expires within
/// [expiringWithinDays] days or has expired; the traffic used is at least
/// [trafficLowPercent] percent of the limit, or all of it. Each active thing is
/// said once: the marks of what was said already are in
/// `Subscription.notifiedAlerts`. A mark whose cause is gone (the subscription
/// was renewed, the provider reset the counter, "expiring" became "expired") is
/// dropped and its alert taken back, so the next time it is said again.
///
/// With [enabled] false nothing new is said and nothing is marked, so it is said
/// when the switch is turned on; the alerts that went out of date are still
/// taken back.
LimitAlertPlan planLimitAlerts(
  Subscription sub,
  DateTime now, {
  required bool enabled,
}) {
  final active = <_Limit, int?>{};

  final expiresAt = sub.expiresAt;
  if (expiresAt != null) {
    final left = expiresAt.difference(now);
    if (left <= Duration.zero) {
      active[_Limit.expired] = null;
    } else if (left <= const Duration(days: expiringWithinDays)) {
      // A part of a day counts as a day: 50 hours left is "3 days".
      active[_Limit.expiring] = (left.inMinutes / Duration.minutesPerDay)
          .ceil();
    }
  }

  final used = sub.usedBytes;
  final limit = sub.dataLimitBytes;
  if (used != null && limit != null && limit > 0) {
    if (used >= limit) {
      active[_Limit.trafficExhausted] = null;
    } else {
      final percent = used * 100 ~/ limit;
      if (percent >= trafficLowPercent) active[_Limit.trafficLow] = percent;
    }
  }

  final marked = sub.notifiedAlerts.toSet();
  final show = <LimitAlertToShow>[];
  final cancel = <AppAlertKind>[];
  final notified = <String>[];
  for (final limitAlert in _Limit.values) {
    final isActive = active.containsKey(limitAlert);
    final wasMarked = marked.contains(limitAlert.key);
    if (isActive && wasMarked) {
      notified.add(limitAlert.key);
    } else if (isActive && enabled) {
      show.add((kind: limitAlert.kind, number: active[limitAlert]));
      notified.add(limitAlert.key);
    } else if (wasMarked) {
      cancel.add(limitAlert.kind);
    }
  }
  return LimitAlertPlan(show: show, cancel: cancel, notified: notified);
}
