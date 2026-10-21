import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/core/theme/data/app_theme_mode.dart';
import 'package:slipstream/core/theme/data/theme_store.dart';

export 'package:slipstream/core/theme/data/app_theme_mode.dart';

@LazySingleton()
class AppThemeCubit extends Cubit<AppThemeState> {
  AppThemeCubit({required ThemeStore themeStore})
    : _themeStore = themeStore,
      super(AppThemeState(mode: themeStore.loadMode()));

  final ThemeStore _themeStore;

  AppThemeMode get mode => state.mode;
  bool get isDark => state.isDark;

  void setMode(AppThemeMode mode) {
    emit(AppThemeState(mode: mode));
    _themeStore.saveMode(mode);
  }
}
