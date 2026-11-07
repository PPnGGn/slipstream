import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/routing/cubit/lan_bypass_cubit.dart';
import 'package:slipstream/features/routing/data/lan_bypass_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<LanBypassStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return LanBypassStore(await SharedPreferences.getInstance());
  }

  test('starts on on a fresh install', () async {
    final cubit = LanBypassCubit(store: await storeWith({}));
    expect(cubit.state, isTrue);
  });

  test('starts from what the store holds', () async {
    final cubit = LanBypassCubit(
      store: await storeWith({'routing_lan_bypass': false}),
    );
    expect(cubit.state, isFalse);
  });

  test('setEnabled emits and stores', () async {
    final store = await storeWith({});
    final cubit = LanBypassCubit(store: store);
    await cubit.setEnabled(enabled: false);
    expect(cubit.state, isFalse);
    expect(store.load(), isFalse);
    await cubit.setEnabled(enabled: true);
    expect(cubit.state, isTrue);
    expect(store.load(), isTrue);
  });

  test('a call that changes nothing emits nothing', () async {
    final cubit = LanBypassCubit(store: await storeWith({}));
    final emitted = <bool>[];
    final sub = cubit.stream.listen(emitted.add);
    await cubit.setEnabled(enabled: true);
    await Future<void>.delayed(Duration.zero);
    expect(emitted, isEmpty);
    await sub.cancel();
  });
}
