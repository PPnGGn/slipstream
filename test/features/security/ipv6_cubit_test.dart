import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/security/cubit/ipv6_cubit.dart';
import 'package:slipstream/features/security/data/ipv6_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Ipv6Store> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return Ipv6Store(await SharedPreferences.getInstance());
  }

  test('starts off on a fresh install', () async {
    final cubit = Ipv6Cubit(store: await storeWith({}));
    expect(cubit.state, isFalse);
  });

  test('starts from what the store holds', () async {
    final cubit = Ipv6Cubit(store: await storeWith({'tunnel_ipv6': true}));
    expect(cubit.state, isTrue);
  });

  test('setEnabled emits and stores', () async {
    final store = await storeWith({});
    final cubit = Ipv6Cubit(store: store);
    await cubit.setEnabled(enabled: true);
    expect(cubit.state, isTrue);
    expect(store.load(), isTrue);
    await cubit.setEnabled(enabled: false);
    expect(cubit.state, isFalse);
    expect(store.load(), isFalse);
  });

  test('a call that changes nothing emits nothing', () async {
    final cubit = Ipv6Cubit(store: await storeWith({}));
    final emitted = <bool>[];
    final sub = cubit.stream.listen(emitted.add);
    await cubit.setEnabled(enabled: false);
    await Future<void>.delayed(Duration.zero);
    expect(emitted, isEmpty);
    await sub.cancel();
  });
}
