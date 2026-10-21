import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/client_identity/data/client_identity_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ClientIdentityStore, SharedPreferences)> storeWith(
    Map<String, Object> values,
  ) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    return (ClientIdentityStore(prefs), prefs);
  }

  test('fresh install has no stored HWID', () async {
    final (store, _) = await storeWith({});

    expect(store.loadRealHwid(), isNull);
  });

  test('save round-trips through load', () async {
    final (store, _) = await storeWith({});

    await store.saveRealHwid('3f2a9c1e-7b4d-4e21-9a0f-5c6d7e8f9a0b');

    expect(
      store.loadRealHwid(),
      equals('3f2a9c1e-7b4d-4e21-9a0f-5c6d7e8f9a0b'),
    );
  });

  test('the value is stored under client_hwid_real', () async {
    final (store, prefs) = await storeWith({});

    await store.saveRealHwid('3f2a9c1e-7b4d-4e21-9a0f-5c6d7e8f9a0b');

    expect(
      prefs.getString('client_hwid_real'),
      equals('3f2a9c1e-7b4d-4e21-9a0f-5c6d7e8f9a0b'),
    );
  });

  test('a stored value the panel would reject loads as null', () async {
    final (store, _) = await storeWith({'client_hwid_real': 'bad!'});

    expect(store.loadRealHwid(), isNull);
  });

  test('an empty stored value loads as null', () async {
    final (store, _) = await storeWith({'client_hwid_real': ''});

    expect(store.loadRealHwid(), isNull);
  });
}
