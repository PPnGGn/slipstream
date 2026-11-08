import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/language/data/app_language.dart';
import 'package:slipstream/features/language/data/language_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<LanguageStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return LanguageStore(await SharedPreferences.getInstance());
  }

  test('fresh install follows the system', () async {
    expect((await storeWith({})).load(), AppLanguage.system);
  });

  test('save round-trips', () async {
    final store = await storeWith({});
    await store.save(AppLanguage.fa);
    expect(store.load(), AppLanguage.fa);
    await store.save(AppLanguage.system);
    expect(store.load(), AppLanguage.system);
  });

  test('an unknown stored value falls back to system', () async {
    final store = await storeWith({'app_language': 'klingon'});
    expect(store.load(), AppLanguage.system);
  });

  test('is stored under the documented key', () async {
    final store = await storeWith({});
    await store.save(AppLanguage.ru);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_language'), 'ru');
  });
}
