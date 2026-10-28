import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/subscriptions/data/subscription_order_store.dart';

void main() {
  Future<SubscriptionOrderStore> store([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    return SubscriptionOrderStore(await SharedPreferences.getInstance());
  }

  test('is empty before anything was saved', () async {
    expect((await store()).load(), isEmpty);
  });

  test('keeps the order it was given', () async {
    final s = await store();

    await s.save(['c', 'a', 'b']);

    expect(s.load(), ['c', 'a', 'b']);
  });

  test('a new save replaces the old order', () async {
    final s = await store({
      'subscription_order': ['a', 'b'],
    });

    await s.save(['b']);

    expect(s.load(), ['b']);
  });
}
