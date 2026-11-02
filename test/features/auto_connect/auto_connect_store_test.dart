import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/auto_connect/data/auto_connect_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AutoConnectStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return AutoConnectStore(await SharedPreferences.getInstance());
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
    expect(prefs.getBool('auto_connect_on_launch'), isTrue);
  });

  test('reads a value stored by an earlier run', () async {
    final store = await storeWith({'auto_connect_on_launch': true});
    expect(store.load(), isTrue);
  });
}
