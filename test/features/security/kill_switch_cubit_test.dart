import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/security/cubit/kill_switch_cubit.dart';
import 'package:slipstream/features/security/data/kill_switch_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<KillSwitchStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return KillSwitchStore(await SharedPreferences.getInstance());
  }

  test('starts on for a fresh install', () async {
    final cubit = KillSwitchCubit(store: await storeWith({}));
    expect(cubit.state, isTrue);
  });

  test('starts from what the store holds', () async {
    final cubit = KillSwitchCubit(
      store: await storeWith({'kill_switch': false}),
    );
    expect(cubit.state, isFalse);
  });

  test('setEnabled emits and stores', () async {
    final store = await storeWith({});
    final cubit = KillSwitchCubit(store: store);
    await cubit.setEnabled(enabled: false);
    expect(cubit.state, isFalse);
    expect(store.load(), isFalse);
    await cubit.setEnabled(enabled: true);
    expect(cubit.state, isTrue);
    expect(store.load(), isTrue);
  });

  test('a call that changes nothing emits nothing', () async {
    final cubit = KillSwitchCubit(store: await storeWith({}));
    final emitted = <bool>[];
    final sub = cubit.stream.listen(emitted.add);
    await cubit.setEnabled(enabled: true);
    await Future<void>.delayed(Duration.zero);
    expect(emitted, isEmpty);
    await sub.cancel();
  });
}
