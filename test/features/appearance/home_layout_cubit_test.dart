import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/appearance/cubit/home_layout_cubit.dart';
import 'package:slipstream/features/appearance/data/home_layout.dart';
import 'package:slipstream/features/appearance/data/home_layout_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HomeLayoutStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return HomeLayoutStore(await SharedPreferences.getInstance());
  }

  test('starts from the stored layout', () async {
    final store = await storeWith({'home_layout': 'compact'});
    expect(HomeLayoutCubit(store: store).state, HomeLayout.compact);
  });

  test('setLayout emits and stores the layout', () async {
    final store = await storeWith({});
    final cubit = HomeLayoutCubit(store: store);

    await cubit.setLayout(HomeLayout.compact);

    expect(cubit.state, HomeLayout.compact);
    expect(store.load(), HomeLayout.compact);
  });

  test('picking the current layout again emits nothing', () async {
    final store = await storeWith({});
    final cubit = HomeLayoutCubit(store: store);
    final emitted = <HomeLayout>[];
    final sub = cubit.stream.listen(emitted.add);

    await cubit.setLayout(HomeLayout.classic);
    await Future<void>.delayed(Duration.zero);

    expect(emitted, isEmpty);
    await sub.cancel();
  });
}
