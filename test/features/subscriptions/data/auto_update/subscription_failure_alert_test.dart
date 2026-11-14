import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/subscription_failure_alert.dart';

final _t = DateTime(2026, 11, 15, 12);

Subscription _sub({String? lastError, DateTime? notifiedAt}) => Subscription(
  id: 's',
  url: 'https://example.com/s',
  name: 'Liberty VPN',
  lastUpdatedAt: _t,
  lastError: lastError,
  failureNotifiedAt: notifiedAt,
);

void main() {
  FailureAlertAction action(
    Subscription before,
    Subscription after, {
    bool enabled = true,
  }) => failureAlertAction(before: before, after: after, enabled: enabled);

  group('a refresh that failed', () {
    test('alerts the first time', () {
      expect(
        action(_sub(), _sub(lastError: 'HTTP error: 502')),
        FailureAlertAction.show,
      );
    });

    // The job runs again every half hour while the subscription fails: one
    // alert for the whole run of failures, not one per attempt.
    test('stays quiet while the alert of this run of failures is out', () {
      final notified = _sub(lastError: 'Timeout', notifiedAt: _t);

      expect(
        action(notified, _sub(lastError: 'Timeout', notifiedAt: _t)),
        FailureAlertAction.none,
      );
    });

    test('stays quiet when the switch is off', () {
      expect(
        action(_sub(), _sub(lastError: 'Timeout'), enabled: false),
        FailureAlertAction.none,
      );
    });
  });

  group('a refresh that worked', () {
    test('takes back the alert of the failures before it', () {
      expect(
        action(
          _sub(lastError: 'Timeout', notifiedAt: _t),
          _sub(), // the factory clears both fields on a success
        ),
        FailureAlertAction.cancel,
      );
    });

    test('has nothing to take back when no alert was out', () {
      expect(action(_sub(), _sub()), FailureAlertAction.none);
    });

    test('takes the alert back also when the switch is off now', () {
      // The user turned the switch off while it was showing: it still must not
      // outlive the failure it was about.
      expect(
        action(
          _sub(lastError: 'Timeout', notifiedAt: _t),
          _sub(),
          enabled: false,
        ),
        FailureAlertAction.cancel,
      );
    });
  });
}
