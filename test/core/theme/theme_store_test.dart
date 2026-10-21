import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/core/theme/data/app_theme_mode.dart';
import 'package:slipstream/core/theme/data/theme_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ThemeStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return ThemeStore(await SharedPreferences.getInstance());
  }

  test('fresh install defaults to light', () async {
    final store = await storeWith({});
    expect(store.loadMode(), AppThemeMode.light);
  });

  for (final mode in AppThemeMode.values) {
    test('${mode.name} round-trips', () async {
      final store = await storeWith({});
      await store.saveMode(mode);
      expect(store.loadMode(), mode);
    });
  }

  test('an unknown stored value falls back to light', () async {
    final store = await storeWith({'app_theme_mode': 'wat'});
    expect(store.loadMode(), AppThemeMode.light);
  });
}
