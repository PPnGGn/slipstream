import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_mode.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_settings.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SplitTunnelStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SplitTunnelStore(await SharedPreferences.getInstance());
  }

  test('fresh install loads the defaults', () async {
    final store = await storeWith({});
    expect(store.load(), const SplitTunnelSettings());
  });

  test('save round-trips every field', () async {
    final store = await storeWith({});
    const settings = SplitTunnelSettings(
      enabled: true,
      mode: SplitTunnelMode.proxy,
      packages: {'com.a', 'com.b'},
      includeSystem: true,
    );
    await store.save(settings);
    expect(store.load(), settings);
  });

  test('reads what an earlier run wrote under the documented keys', () async {
    final store = await storeWith({
      'split_tunnel_enabled': true,
      'split_tunnel_mode': 'proxy',
      'split_tunnel_packages': ['com.a'],
      'split_tunnel_include_system': true,
    });
    final settings = store.load();
    expect(settings.enabled, isTrue);
    expect(settings.mode, SplitTunnelMode.proxy);
    expect(settings.packages, {'com.a'});
    expect(settings.includeSystem, isTrue);
  });

  test('an unknown stored mode falls back to bypass', () async {
    final store = await storeWith({'split_tunnel_mode': 'wat'});
    expect(store.load().mode, SplitTunnelMode.bypass);
  });

  test('saving an empty list clears the stored packages', () async {
    final store = await storeWith({});
    await store.save(const SplitTunnelSettings(packages: {'com.a'}));
    await store.save(const SplitTunnelSettings());
    expect(store.load().packages, isEmpty);
  });
}
