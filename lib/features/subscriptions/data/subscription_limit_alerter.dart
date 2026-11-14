import 'package:injectable/injectable.dart';
import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/features/notifications/data/app_alerts.dart';
import 'package:slipstream/features/notifications/data/notifications_store.dart';
import 'package:slipstream/features/subscriptions/data/subscription_limit_alerts.dart';

/// Raises and takes back the alerts about a subscription's time and traffic
/// (see planLimitAlerts for the rules). Shared by the app (after a refresh) and
/// the background job (after a refresh and for every other subscription it
/// looks at), so a subscription that is about to run out says so whichever of
/// them sees it first.
@lazySingleton
class SubscriptionLimitAlerter {
  SubscriptionLimitAlerter(
    this._notifications,
    this._alerts, {
    @ignoreParam DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final NotificationsStore _notifications;
  final AppAlerts _alerts;
  final DateTime Function() _now;

  /// [sub] with its `notifiedAlerts` brought up to date. The caller saves it
  /// when it is not the same object: the marks are what keeps the next look
  /// from saying it all again. The very same object comes back when there is
  /// nothing to say and nothing to take back.
  Future<Subscription> apply(Subscription sub) async {
    final plan = planLimitAlerts(
      sub,
      _now(),
      enabled: _notifications.load().subscriptionLimits,
    );
    for (final kind in plan.cancel) {
      await _alerts.cancel(kind, sub.name);
    }
    for (final alert in plan.show) {
      await _alerts.show(
        alert.kind,
        subscriptionName: sub.name,
        number: alert.number,
      );
    }
    if (_sameMarks(sub.notifiedAlerts, plan.notified)) return sub;
    return sub.copyWith(notifiedAlerts: plan.notified);
  }

  /// Takes back every alert [sub] could have out, for a subscription that was
  /// deleted: an alert about something that is gone would only confuse. Covers
  /// "did not update" too, which the background job raises.
  Future<void> forget(Subscription sub) async {
    for (final kind in AppAlertKind.values) {
      await _alerts.cancel(kind, sub.name);
    }
  }

  bool _sameMarks(List<String> a, List<String> b) =>
      a.length == b.length && a.every(b.contains);
}
