import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/subscriptions/cubit/subscription_auto_update_cubit.dart';
import 'package:slipstream/features/subscriptions/cubit/subscription_auto_updater.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/auto_update_interval.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/subscription_update_settings_store.dart';

class _FakeUpdater extends Fake implements SubscriptionAutoUpdater {
  var reschedules = 0;

  @override
  void reschedule() => reschedules++;
}

void main() {
  late SubscriptionUpdateSettingsStore store;
  late _FakeUpdater updater;

  Future<SubscriptionAutoUpdateCubit> cubit([
    Map<String, Object> prefs = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(prefs);
    store = SubscriptionUpdateSettingsStore(
      await SharedPreferences.getInstance(),
    );
    updater = _FakeUpdater();
    return SubscriptionAutoUpdateCubit(store, updater);
  }

  test('starts from the stored setting', () async {
    final c = await cubit({'subscription_auto_update': 'h3'});

    expect(c.state, AutoUpdateInterval.h3);
  });

  test('select saves, emits and reschedules', () async {
    final c = await cubit();

    await c.select(AutoUpdateInterval.off);

    expect(c.state, AutoUpdateInterval.off);
    expect(store.loadInterval(), AutoUpdateInterval.off);
    expect(updater.reschedules, 1);
  });

  test('selecting the current value does nothing', () async {
    final c = await cubit();

    await c.select(AutoUpdateInterval.h12);

    expect(updater.reschedules, 0);
  });
}
