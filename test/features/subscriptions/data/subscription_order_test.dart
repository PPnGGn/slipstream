import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/stored_subscription/stored_subscription.dart';
import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/features/subscriptions/data/subscription_order.dart';

StoredSubscription _stored(String id) => StoredSubscription(
  subscription: Subscription(
    id: id,
    url: null,
    name: id,
    lastUpdatedAt: DateTime(2026),
  ),
  servers: const [],
);

List<String> _ids(List<StoredSubscription> subs) => [
  for (final s in subs) s.subscription.id,
];

void main() {
  group('orderSubscriptions', () {
    test('follows the saved order', () {
      final ordered = orderSubscriptions(
        [_stored('a'), _stored('b'), _stored('c')],
        ['c', 'a', 'b'],
      );

      expect(_ids(ordered), ['c', 'a', 'b']);
    });

    test('puts subscriptions the order does not know at the end, by id', () {
      final ordered = orderSubscriptions(
        [_stored('z'), _stored('b'), _stored('a'), _stored('m')],
        ['m'],
      );

      expect(_ids(ordered), ['m', 'a', 'b', 'z']);
    });

    test('ignores saved ids that are gone', () {
      final ordered = orderSubscriptions(
        [_stored('a'), _stored('b')],
        ['gone', 'b', 'a'],
      );

      expect(_ids(ordered), ['b', 'a']);
    });

    test('without a saved order it is sorted by id, not by disk order', () {
      final ordered = orderSubscriptions([_stored('b'), _stored('a')], []);

      expect(_ids(ordered), ['a', 'b']);
    });
  });

  group('moveItem', () {
    test('moves an item down; the new index is after the removal', () {
      expect(moveItem(['a', 'b', 'c', 'd'], 0, 2), ['b', 'c', 'a', 'd']);
    });

    test('moves an item up', () {
      expect(moveItem(['a', 'b', 'c', 'd'], 3, 1), ['a', 'd', 'b', 'c']);
    });

    test('the same place changes nothing', () {
      expect(moveItem(['a', 'b'], 1, 1), ['a', 'b']);
    });

    test('does not touch the list it was given', () {
      final source = ['a', 'b', 'c'];

      moveItem(source, 0, 2);

      expect(source, ['a', 'b', 'c']);
    });
  });
}
