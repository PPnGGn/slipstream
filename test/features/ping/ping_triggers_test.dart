import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/stored_subscription/stored_subscription.dart';
import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/features/ping/presentation/ping_triggers.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';

final _t0 = DateTime(2026, 10, 22, 8);

StoredSubscription _stored(String id, DateTime updatedAt, {String? error}) =>
    StoredSubscription(
      subscription: Subscription(
        id: id,
        url: 'https://example.com/$id',
        name: id,
        lastUpdatedAt: updatedAt,
        lastError: error,
      ),
      servers: const [],
    );

SubscriptionsState _state(List<StoredSubscription> subs) =>
    SubscriptionsState(subscriptions: subs, isLoaded: true);

void main() {
  group('refreshedSubscriptionIds', () {
    test('lists subscriptions whose update time moved', () {
      final later = _t0.add(const Duration(hours: 1));
      expect(
        refreshedSubscriptionIds(
          _state([_stored('a', _t0), _stored('b', _t0)]),
          _state([_stored('a', later), _stored('b', _t0)]),
        ),
        ['a'],
      );
    });

    test('ignores a failed attempt (update time unchanged)', () {
      expect(
        refreshedSubscriptionIds(
          _state([_stored('a', _t0)]),
          _state([_stored('a', _t0, error: 'Timeout')]),
        ),
        isEmpty,
      );
    });

    test('ignores added and removed subscriptions', () {
      expect(
        refreshedSubscriptionIds(
          _state([_stored('gone', _t0)]),
          _state([_stored('new', _t0)]),
        ),
        isEmpty,
      );
    });
  });

  group('shouldRepingOnResume', () {
    test('re-pings when the last full run is older than the threshold', () {
      expect(shouldRepingOnResume(_t0, _t0.add(repingOnResumeAfter)), isTrue);
    });

    test('skips a quick switch away and back', () {
      expect(
        shouldRepingOnResume(_t0, _t0.add(const Duration(minutes: 2))),
        isFalse,
      );
    });

    test('re-pings when no full run happened yet', () {
      expect(shouldRepingOnResume(null, _t0), isTrue);
    });
  });
}
