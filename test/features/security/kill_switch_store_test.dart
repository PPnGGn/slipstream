import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/security/data/kill_switch_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<KillSwitchStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return KillSwitchStore(await SharedPreferences.getInstance());
  }

  test('fresh install defaults to on', () async {
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
    expect(prefs.getBool('kill_switch'), isFalse);
  });

  test('reads an off value stored by an earlier run', () async {
    final store = await storeWith({'kill_switch': false});
    expect(store.load(), isFalse);
  });
}
