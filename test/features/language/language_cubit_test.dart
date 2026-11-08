import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/language/cubit/language_cubit.dart';
import 'package:slipstream/features/language/data/app_language.dart';
import 'package:slipstream/features/language/data/language_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<LanguageStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return LanguageStore(await SharedPreferences.getInstance());
  }

  test('starts on system for a fresh install', () async {
    final cubit = LanguageCubit(store: await storeWith({}));
    expect(cubit.state, AppLanguage.system);
  });

  test('starts from what the store holds', () async {
    final cubit = LanguageCubit(store: await storeWith({'app_language': 'zh'}));
    expect(cubit.state, AppLanguage.zh);
  });

  test('setLanguage emits and stores', () async {
    final store = await storeWith({});
    final cubit = LanguageCubit(store: store);
    await cubit.setLanguage(AppLanguage.ru);
    expect(cubit.state, AppLanguage.ru);
    expect(store.load(), AppLanguage.ru);
  });

  test('a call that changes nothing emits nothing', () async {
    final cubit = LanguageCubit(store: await storeWith({}));
    final emitted = <AppLanguage>[];
    final sub = cubit.stream.listen(emitted.add);
    await cubit.setLanguage(AppLanguage.system);
    await Future<void>.delayed(Duration.zero);
    expect(emitted, isEmpty);
    await sub.cancel();
  });
}
