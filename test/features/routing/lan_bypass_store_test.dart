import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/routing/data/lan_bypass_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<LanBypassStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return LanBypassStore(await SharedPreferences.getInstance());
  }

  test('on by default: LAN was always sent direct before the switch existed', () async {
    final store = await storeWith({});
    expect(store.load(), isTrue);
  });

  test('save round-trips', () async {
    final store = await storeWith({});
    await store.save(enabled: false);
    expect(store.load(), isFalse);
    await store.save(enabled: true);
    expect(store.load(), isTrue);
  });

  test('is stored under the documented key', () async {
    final store = await storeWith({});
    await store.save(enabled: false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('routing_lan_bypass'), isFalse);
  });
}
