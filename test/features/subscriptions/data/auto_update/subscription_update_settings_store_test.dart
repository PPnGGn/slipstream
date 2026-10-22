import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/auto_update_interval.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/subscription_update_settings_store.dart';

void main() {
  Future<SubscriptionUpdateSettingsStore> storeWith(
    Map<String, Object> values,
  ) async {
    SharedPreferences.setMockInitialValues(values);
    return SubscriptionUpdateSettingsStore(
      await SharedPreferences.getInstance(),
    );
  }

  test('defaults to every 12 hours', () async {
    final store = await storeWith({});

    expect(store.loadInterval(), AutoUpdateInterval.h12);
  });

  test('save round-trips', () async {
    final store = await storeWith({});

    await store.saveInterval(AutoUpdateInterval.off);
    expect(store.loadInterval(), AutoUpdateInterval.off);

    await store.saveInterval(AutoUpdateInterval.h3);
    expect(store.loadInterval(), AutoUpdateInterval.h3);
  });

  test('an unknown stored value falls back to the default', () async {
    final store = await storeWith({'subscription_auto_update': 'weekly'});

    expect(store.loadInterval(), AutoUpdateInterval.h12);
  });

  test('hours match the option names', () {
    expect(AutoUpdateInterval.off.hours, isNull);
    expect(
      [
        AutoUpdateInterval.h1,
        AutoUpdateInterval.h3,
        AutoUpdateInterval.h6,
        AutoUpdateInterval.h12,
        AutoUpdateInterval.h24,
      ].map((i) => i.hours),
      [1, 3, 6, 12, 24],
    );
  });
}
