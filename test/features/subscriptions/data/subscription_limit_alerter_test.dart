import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/features/notifications/data/app_alerts.dart';
import 'package:slipstream/features/notifications/data/notifications_store.dart';
import 'package:slipstream/features/subscriptions/data/subscription_limit_alerter.dart';

import 'subscription_fakes.dart';

final _now = DateTime(2026, 11, 15, 12);

Subscription _sub({
  DateTime? expiresAt,
  List<String> notified = const [],
  String name = 'Liberty VPN',
}) => Subscription(
  id: 's',
  url: 'https://example.com/s',
  name: name,
  lastUpdatedAt: _now,
  expiresAt: expiresAt,
  notifiedAlerts: notified,
);

void main() {
  late RecordingAppAlerts alerts;

  Future<SubscriptionLimitAlerter> alerter([
    Map<String, Object> prefs = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(prefs);
    alerts = RecordingAppAlerts();
    return SubscriptionLimitAlerter(
      NotificationsStore(await SharedPreferences.getInstance()),
      alerts,
      now: () => _now,
    );
  }

  test('raises what the plan says, by the name of the subscription', () async {
    final result = await (await alerter()).apply(
      _sub(expiresAt: _now.add(const Duration(days: 2))),
    );

    expect(alerts.shown, [
      (kind: AppAlertKind.subscriptionExpiring, name: 'Liberty VPN', number: 2),
    ]);
    expect(result.notifiedAlerts, ['expiring']);
  });

  test('says it once: the second look finds the mark', () async {
    final a = await alerter();
    final first = await a.apply(
      _sub(expiresAt: _now.add(const Duration(days: 2))),
    );

    await a.apply(first);

    expect(alerts.shown, hasLength(1));
  });

  test('gives back the very same subscription when nothing changes', () async {
    final sub = _sub();

    expect(identical(await (await alerter()).apply(sub), sub), isTrue);
    expect(alerts.shown, isEmpty);
    expect(alerts.cancelled, isEmpty);
  });

  test('takes an out of date alert back and clears its mark', () async {
    final result = await (await alerter()).apply(
      _sub(
        expiresAt: _now.add(const Duration(days: 30)),
        notified: ['expiring'],
      ),
    );

    expect(alerts.cancelled, [
      (AppAlertKind.subscriptionExpiring, 'Liberty VPN'),
    ]);
    expect(result.notifiedAlerts, isEmpty);
  });

  test('forgetting a subscription takes back every alert it had', () async {
    await (await alerter()).forget(_sub(name: 'Gone VPN'));

    expect(alerts.cancelled.map((c) => c.$1).toSet(), {
      AppAlertKind.subscriptionFailed,
      AppAlertKind.subscriptionExpiring,
      AppAlertKind.subscriptionExpired,
      AppAlertKind.trafficLow,
      AppAlertKind.trafficExhausted,
    });
    expect(alerts.cancelled.every((c) => c.$2 == 'Gone VPN'), isTrue);
  });

  test('with the switch off it raises nothing and leaves no mark', () async {
    final result = await (await alerter({
      'notify_subscription_limits': false,
    })).apply(_sub(expiresAt: _now.add(const Duration(days: 1))));

    expect(alerts.shown, isEmpty);
    expect(result.notifiedAlerts, isEmpty);
  });
}
