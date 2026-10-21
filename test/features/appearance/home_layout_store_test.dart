import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/appearance/data/home_layout.dart';
import 'package:slipstream/features/appearance/data/home_layout_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HomeLayoutStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return HomeLayoutStore(await SharedPreferences.getInstance());
  }

  test('fresh install defaults to classic', () async {
    final store = await storeWith({});
    expect(store.load(), HomeLayout.classic);
  });

  for (final layout in HomeLayout.values) {
    test('${layout.name} round-trips', () async {
      final store = await storeWith({});
      await store.save(layout);
      expect(store.load(), layout);
    });
  }

  test('an unknown stored value falls back to classic', () async {
    final store = await storeWith({'home_layout': 'full'});
    expect(store.load(), HomeLayout.classic);
  });
}
