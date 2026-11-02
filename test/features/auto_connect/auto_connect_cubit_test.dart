import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/auto_connect/cubit/auto_connect_cubit.dart';
import 'package:slipstream/features/auto_connect/data/auto_connect_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AutoConnectStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return AutoConnectStore(await SharedPreferences.getInstance());
  }

  test('starts off on a fresh install', () async {
    final cubit = AutoConnectCubit(store: await storeWith({}));
    expect(cubit.state, isFalse);
  });

  test('starts from what the store holds', () async {
    final cubit = AutoConnectCubit(
      store: await storeWith({'auto_connect_on_launch': true}),
    );
    expect(cubit.state, isTrue);
  });

  test('setEnabled emits and stores', () async {
    final store = await storeWith({});
    final cubit = AutoConnectCubit(store: store);
    await cubit.setEnabled(enabled: true);
    expect(cubit.state, isTrue);
    expect(store.load(), isTrue);
    await cubit.setEnabled(enabled: false);
    expect(cubit.state, isFalse);
    expect(store.load(), isFalse);
  });

  test('a call that changes nothing emits nothing', () async {
    final cubit = AutoConnectCubit(store: await storeWith({}));
    final emitted = <bool>[];
    final sub = cubit.stream.listen(emitted.add);
    await cubit.setEnabled(enabled: false);
    await Future<void>.delayed(Duration.zero);
    expect(emitted, isEmpty);
    await sub.cancel();
  });
}
