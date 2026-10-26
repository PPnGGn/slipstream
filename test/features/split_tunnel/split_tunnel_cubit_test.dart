import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/split_tunnel/cubit/split_tunnel_cubit.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_mode.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_settings.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SplitTunnelStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SplitTunnelStore(await SharedPreferences.getInstance());
  }

  test('starts from what the store holds', () async {
    final store = await storeWith({
      'split_tunnel_enabled': true,
      'split_tunnel_packages': ['com.a'],
    });
    final cubit = SplitTunnelCubit(store: store);
    expect(cubit.state.enabled, isTrue);
    expect(cubit.state.packages, {'com.a'});
  });

  test('setEnabled emits and stores', () async {
    final store = await storeWith({});
    final cubit = SplitTunnelCubit(store: store);
    await cubit.setEnabled(enabled: true);
    expect(cubit.state.enabled, isTrue);
    expect(store.load().enabled, isTrue);
  });

  test('setMode emits and stores, the picked list stays', () async {
    final store = await storeWith({});
    final cubit = SplitTunnelCubit(store: store);
    await cubit.setAppSelected('com.a', selected: true);
    await cubit.setMode(SplitTunnelMode.proxy);
    expect(cubit.state.mode, SplitTunnelMode.proxy);
    expect(cubit.state.packages, {'com.a'});
    expect(store.load().mode, SplitTunnelMode.proxy);
  });

  test('setAppSelected adds and removes a package', () async {
    final store = await storeWith({});
    final cubit = SplitTunnelCubit(store: store);
    await cubit.setAppSelected('com.a', selected: true);
    await cubit.setAppSelected('com.b', selected: true);
    expect(cubit.state.packages, {'com.a', 'com.b'});
    await cubit.setAppSelected('com.a', selected: false);
    expect(cubit.state.packages, {'com.b'});
    expect(store.load().packages, {'com.b'});
  });

  test('setIncludeSystem emits and stores', () async {
    final store = await storeWith({});
    final cubit = SplitTunnelCubit(store: store);
    await cubit.setIncludeSystem(include: true);
    expect(cubit.state.includeSystem, isTrue);
    expect(store.load().includeSystem, isTrue);
  });

  test('a call that changes nothing emits nothing', () async {
    final store = await storeWith({});
    final cubit = SplitTunnelCubit(store: store);
    final emitted = <SplitTunnelSettings>[];
    final sub = cubit.stream.listen(emitted.add);
    await cubit.setEnabled(enabled: false);
    await cubit.setMode(SplitTunnelMode.bypass);
    await cubit.setAppSelected('com.a', selected: false);
    await cubit.setIncludeSystem(include: false);
    await Future<void>.delayed(Duration.zero);
    expect(emitted, isEmpty);
    await sub.cancel();
  });
}
