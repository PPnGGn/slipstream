import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/security/data/ipv6_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Ipv6Store> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return Ipv6Store(await SharedPreferences.getInstance());
  }

  test('fresh install defaults to off', () async {
    final store = await storeWith({});
    expect(store.load(), isFalse);
  });

  test('save round-trips', () async {
    final store = await storeWith({});
    await store.save(enabled: true);
    expect(store.load(), isTrue);
    await store.save(enabled: false);
    expect(store.load(), isFalse);
  });

  test('is stored under the documented key', () async {
    final store = await storeWith({});
    await store.save(enabled: true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('tunnel_ipv6'), isTrue);
  });

  test('reads a value stored by an earlier run', () async {
    final store = await storeWith({'tunnel_ipv6': true});
    expect(store.load(), isTrue);
  });
}
