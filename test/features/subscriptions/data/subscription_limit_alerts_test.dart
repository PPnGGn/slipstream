import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/features/notifications/data/app_alerts.dart';
import 'package:slipstream/features/subscriptions/data/subscription_limit_alerts.dart';

final _now = DateTime(2026, 11, 15, 12);
const _gb = 1024 * 1024 * 1024;

Subscription _sub({
  DateTime? expiresAt,
  int? used,
  int? limit,
  List<String> notified = const [],
}) => Subscription(
  id: 's',
  url: 'https://example.com/s',
  name: 'Liberty VPN',
  lastUpdatedAt: _now,
  expiresAt: expiresAt,
  usedBytes: used,
  dataLimitBytes: limit,
  notifiedAlerts: notified,
);

void main() {
  LimitAlertPlan plan(Subscription sub, {bool enabled = true}) =>
      planLimitAlerts(sub, _now, enabled: enabled);

  List<(AppAlertKind, int?)> shown(LimitAlertPlan p) => [
    for (final a in p.show) (a.kind, a.number),
  ];

  group('nothing to say', () {
    test('a subscription with no expiry and no limit', () {
      final p = plan(_sub());

      expect(p.show, isEmpty);
      expect(p.cancel, isEmpty);
      expect(p.notified, isEmpty);
    });

    test('plenty of time and traffic left', () {
      final p = plan(
        _sub(
          expiresAt: _now.add(const Duration(days: 30)),
          used: 10 * _gb,
          limit: 100 * _gb,
        ),
      );

      expect(p.show, isEmpty);
    });

    test('an unlimited subscription: a limit of 0 is "no limit"', () {
      expect(plan(_sub(used: 5 * _gb, limit: 0)).show, isEmpty);
    });

    test('a limit with no figure of the traffic used', () {
      expect(plan(_sub(limit: 100 * _gb)).show, isEmpty);
    });
  });

  group('expiry', () {
    test('within three days: says how many days are left', () {
      expect(shown(plan(_sub(expiresAt: _now.add(const Duration(days: 3))))), [
        (AppAlertKind.subscriptionExpiring, 3),
      ]);
    });

    test('a part of a day counts as a day', () {
      expect(
        shown(plan(_sub(expiresAt: _now.add(const Duration(hours: 50))))),
        [(AppAlertKind.subscriptionExpiring, 3)],
      );
      expect(shown(plan(_sub(expiresAt: _now.add(const Duration(hours: 2))))), [
        (AppAlertKind.subscriptionExpiring, 1),
      ]);
    });

    test('four days is not yet worth a word', () {
      expect(
        plan(_sub(expiresAt: _now.add(const Duration(days: 4)))).show,
        isEmpty,
      );
    });

    test('past its time: expired', () {
      expect(
        shown(plan(_sub(expiresAt: _now.subtract(const Duration(hours: 1))))),
        [(AppAlertKind.subscriptionExpired, null)],
      );
    });

    test('the moment of expiry is expired', () {
      expect(shown(plan(_sub(expiresAt: _now))), [
        (AppAlertKind.subscriptionExpired, null),
      ]);
    });

    test('is said once: a notified alert stays quiet', () {
      final p = plan(
        _sub(
          expiresAt: _now.add(const Duration(days: 2)),
          notified: ['expiring'],
        ),
      );

      expect(p.show, isEmpty);
      expect(p.notified, ['expiring']);
    });

    test('running out turns into expired: the old alert is taken back', () {
      final p = plan(
        _sub(
          expiresAt: _now.subtract(const Duration(minutes: 5)),
          notified: ['expiring'],
        ),
      );

      expect(shown(p), [(AppAlertKind.subscriptionExpired, null)]);
      expect(p.cancel, [AppAlertKind.subscriptionExpiring]);
      expect(p.notified, ['expired']);
    });

    test('a renewed subscription takes its alert back and may alert again', () {
      final renewed = _sub(
        expiresAt: _now.add(const Duration(days: 30)),
        notified: ['expiring'],
      );

      final p = plan(renewed);

      expect(p.show, isEmpty);
      expect(p.cancel, [AppAlertKind.subscriptionExpiring]);
      expect(p.notified, isEmpty);
    });
  });

  group('traffic', () {
    test('under 90 percent: quiet', () {
      expect(plan(_sub(used: 89 * _gb, limit: 100 * _gb)).show, isEmpty);
    });

    test('from 90 percent: running out, with the percent', () {
      expect(shown(plan(_sub(used: 90 * _gb, limit: 100 * _gb))), [
        (AppAlertKind.trafficLow, 90),
      ]);
      expect(shown(plan(_sub(used: 99 * _gb, limit: 100 * _gb))), [
        (AppAlertKind.trafficLow, 99),
      ]);
    });

    test('all used, or more than all: exhausted', () {
      expect(shown(plan(_sub(used: 100 * _gb, limit: 100 * _gb))), [
        (AppAlertKind.trafficExhausted, null),
      ]);
      expect(shown(plan(_sub(used: 120 * _gb, limit: 100 * _gb))), [
        (AppAlertKind.trafficExhausted, null),
      ]);
    });

    test('running out turns into exhausted: the old alert is taken back', () {
      final p = plan(
        _sub(used: 100 * _gb, limit: 100 * _gb, notified: ['trafficLow']),
      );

      expect(shown(p), [(AppAlertKind.trafficExhausted, null)]);
      expect(p.cancel, [AppAlertKind.trafficLow]);
      expect(p.notified, ['trafficExhausted']);
    });

    test('the provider reset the counter: the alert goes, may come again', () {
      final p = plan(
        _sub(used: 2 * _gb, limit: 100 * _gb, notified: ['trafficLow']),
      );

      expect(p.cancel, [AppAlertKind.trafficLow]);
      expect(p.notified, isEmpty);
    });
  });

  group('both at once', () {
    test('expiry and traffic are told separately', () {
      final p = plan(
        _sub(
          expiresAt: _now.add(const Duration(days: 1)),
          used: 95 * _gb,
          limit: 100 * _gb,
        ),
      );

      expect(shown(p), [
        (AppAlertKind.subscriptionExpiring, 1),
        (AppAlertKind.trafficLow, 95),
      ]);
      expect(p.notified, ['expiring', 'trafficLow']);
    });
  });

  group('with the switch off', () {
    test('says nothing and marks nothing, so it can say it when turned on', () {
      final p = plan(
        _sub(expiresAt: _now.add(const Duration(days: 1))),
        enabled: false,
      );

      expect(p.show, isEmpty);
      expect(p.notified, isEmpty);
    });

    test('still takes back an alert whose cause is gone', () {
      final p = plan(
        _sub(
          expiresAt: _now.add(const Duration(days: 30)),
          notified: ['expiring'],
        ),
        enabled: false,
      );

      expect(p.cancel, [AppAlertKind.subscriptionExpiring]);
      expect(p.notified, isEmpty);
    });
  });

  test('a mark this version does not know is dropped, not taken back', () {
    final p = plan(_sub(notified: ['somethingFromTheFuture']));

    expect(p.cancel, isEmpty);
    expect(p.notified, isEmpty);
  });
}
