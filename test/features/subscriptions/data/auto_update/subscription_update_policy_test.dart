import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/auto_update_interval.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/subscription_update_policy.dart';

final _updatedAt = DateTime(2026, 10, 22, 8);

Subscription _sub({
  String id = 'sub',
  String? url = 'https://example.com/sub',
  int? providerHours,
  DateTime? updatedAt,
  DateTime? lastAttemptAt,
  String? lastError,
}) => Subscription(
  id: id,
  url: url,
  name: 'Test',
  lastUpdatedAt: updatedAt ?? _updatedAt,
  updateIntervalHours: providerHours,
  lastAttemptAt: lastAttemptAt,
  lastError: lastError,
);

void main() {
  group('effectiveUpdateInterval', () {
    test('a manual (non-URL) subscription is never auto-updated', () {
      expect(
        effectiveUpdateInterval(_sub(url: null), AutoUpdateInterval.h12),
        isNull,
      );
    });

    test('off disables auto-update even with a provider interval', () {
      expect(
        effectiveUpdateInterval(_sub(providerHours: 6), AutoUpdateInterval.off),
        isNull,
      );
    });

    test('the provider interval wins over the setting', () {
      expect(
        effectiveUpdateInterval(_sub(providerHours: 6), AutoUpdateInterval.h24),
        const Duration(hours: 6),
      );
    });

    test('without a provider interval the setting is used', () {
      expect(
        effectiveUpdateInterval(_sub(), AutoUpdateInterval.h3),
        const Duration(hours: 3),
      );
    });

    test('a zero or negative provider interval is ignored', () {
      expect(
        effectiveUpdateInterval(_sub(providerHours: 0), AutoUpdateInterval.h12),
        const Duration(hours: 12),
      );
      expect(
        effectiveUpdateInterval(
          _sub(providerHours: -5),
          AutoUpdateInterval.h12,
        ),
        const Duration(hours: 12),
      );
    });
  });

  group('nextUpdateAt', () {
    test('is the last update plus the interval', () {
      expect(
        nextUpdateAt(_sub(), AutoUpdateInterval.h12),
        _updatedAt.add(const Duration(hours: 12)),
      );
    });

    test('is null when auto-update does not apply', () {
      expect(nextUpdateAt(_sub(), AutoUpdateInterval.off), isNull);
    });

    test('after a failed attempt, retries 30 minutes after the attempt', () {
      final attempt = _updatedAt.add(const Duration(hours: 13));
      expect(
        nextUpdateAt(
          _sub(lastAttemptAt: attempt, lastError: 'Timeout'),
          AutoUpdateInterval.h12,
        ),
        attempt.add(const Duration(minutes: 30)),
      );
    });

    test('a failed early manual refresh does not bring the schedule '
        'forward', () {
      final attempt = _updatedAt.add(const Duration(hours: 1));
      expect(
        nextUpdateAt(
          _sub(lastAttemptAt: attempt, lastError: 'Timeout'),
          AutoUpdateInterval.h12,
        ),
        _updatedAt.add(const Duration(hours: 12)),
      );
    });

    test('a successful attempt (no error) keeps the normal schedule', () {
      expect(
        nextUpdateAt(_sub(lastAttemptAt: _updatedAt), AutoUpdateInterval.h6),
        _updatedAt.add(const Duration(hours: 6)),
      );
    });
  });

  group('isUpdateDue', () {
    final next = _updatedAt.add(const Duration(hours: 12));

    test('is due once the interval has passed', () {
      expect(isUpdateDue(_sub(), AutoUpdateInterval.h12, next), isTrue);
      expect(
        isUpdateDue(
          _sub(),
          AutoUpdateInterval.h12,
          next.add(const Duration(days: 3)),
        ),
        isTrue,
      );
    });

    test('is due a few minutes early, so a periodic tick never just '
        'misses it', () {
      expect(
        isUpdateDue(
          _sub(),
          AutoUpdateInterval.h12,
          next.subtract(const Duration(minutes: 4)),
        ),
        isTrue,
      );
    });

    test('is not due well before the interval', () {
      expect(
        isUpdateDue(
          _sub(),
          AutoUpdateInterval.h12,
          next.subtract(const Duration(minutes: 10)),
        ),
        isFalse,
      );
    });

    test('is never due when auto-update is off', () {
      expect(
        isUpdateDue(
          _sub(),
          AutoUpdateInterval.off,
          next.add(const Duration(days: 30)),
        ),
        isFalse,
      );
    });
  });

  group('delayUntilNextUpdate', () {
    test('waits for the nearest subscription', () {
      final now = _updatedAt.add(const Duration(hours: 1));
      expect(
        delayUntilNextUpdate(
          [_sub(id: 'a', providerHours: 6), _sub(id: 'b', providerHours: 3)],
          AutoUpdateInterval.h12,
          now,
        ),
        const Duration(hours: 2),
      );
    });

    test('is zero when a subscription is already overdue', () {
      expect(
        delayUntilNextUpdate(
          [_sub()],
          AutoUpdateInterval.h1,
          _updatedAt.add(const Duration(hours: 5)),
        ),
        Duration.zero,
      );
    });

    test('is null when nothing is auto-updated', () {
      expect(
        delayUntilNextUpdate(
          [_sub(url: null)],
          AutoUpdateInterval.h12,
          _updatedAt,
        ),
        isNull,
      );
      expect(
        delayUntilNextUpdate([_sub()], AutoUpdateInterval.off, _updatedAt),
        isNull,
      );
    });
  });
}
