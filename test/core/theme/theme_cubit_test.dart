import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/core/theme/app_palette.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/theme/data/theme_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ThemeStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return ThemeStore(await SharedPreferences.getInstance());
  }

  test('starts from the stored mode', () async {
    final store = await storeWith({'app_theme_mode': 'phosphor'});
    final cubit = AppThemeCubit(themeStore: store);
    expect(cubit.state.mode, AppThemeMode.phosphor);
    expect(cubit.state.palette, same(AppPalette.phosphor));
  });

  test('setMode emits the matching palette and stores the mode', () async {
    final store = await storeWith({});
    final cubit = AppThemeCubit(themeStore: store);

    cubit.setMode(AppThemeMode.dark);

    expect(cubit.state.mode, AppThemeMode.dark);
    expect(cubit.state.palette, same(AppPalette.dark));
    expect(store.loadMode(), AppThemeMode.dark);
  });

  test('toggleTheme cycles light → dark → phosphor → light', () async {
    final store = await storeWith({});
    final cubit = AppThemeCubit(themeStore: store);

    final seen = <AppThemeMode>[];
    for (var i = 0; i < 3; i++) {
      cubit.toggleTheme();
      seen.add(cubit.mode);
    }

    expect(seen, [
      AppThemeMode.dark,
      AppThemeMode.phosphor,
      AppThemeMode.light,
    ]);
  });

  test('phosphor counts as a dark theme', () {
    const state = AppThemeState(mode: AppThemeMode.phosphor);
    expect(state.isDark, isTrue);
    expect(state.palette.brightness, Brightness.dark);
    expect(const AppThemeState(mode: AppThemeMode.light).isDark, isFalse);
  });
}
