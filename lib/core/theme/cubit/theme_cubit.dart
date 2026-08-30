import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/core/theme/data/theme_store.dart';

enum AppThemeMode { light, dark }

@LazySingleton()
class AppThemeCubit extends Cubit<AppThemeMode> {
  AppThemeCubit({required ThemeStore themeStore})
    : _themeStore = themeStore,
      super(themeStore.loadIsDark() ? AppThemeMode.dark : AppThemeMode.light);

  final ThemeStore _themeStore;

  bool get isDark => state == AppThemeMode.dark;

  void toggleTheme() {
    final next = state == AppThemeMode.light
        ? AppThemeMode.dark
        : AppThemeMode.light;
    emit(next);
    _themeStore.saveIsDark(next == AppThemeMode.dark);
  }
}
