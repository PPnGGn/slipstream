import 'dart:ui';

import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/core/theme/data/app_theme_mode.dart';
import 'package:slipstream/core/theme/data/theme_store.dart';

export 'package:slipstream/core/theme/data/app_theme_mode.dart';

@LazySingleton()
class AppThemeCubit extends Cubit<AppThemeState> with WidgetsBindingObserver {
  AppThemeCubit({required ThemeStore themeStore})
    : _themeStore = themeStore,
      super(_resolve(themeStore.loadMode())) {
    WidgetsBinding.instance.addObserver(this);
  }

  final ThemeStore _themeStore;

  AppThemeMode get mode => state.mode;
  bool get isDark => state.isDark;

  static bool _platformIsDark() =>
      PlatformDispatcher.instance.platformBrightness == Brightness.dark;

  static AppThemeState _resolve(AppThemeMode mode) => AppThemeState(
    mode: mode,
    isDark: switch (mode) {
      AppThemeMode.dark => true,
      AppThemeMode.light => false,
      AppThemeMode.system => _platformIsDark(),
    },
  );

  @override
  void didChangePlatformBrightness() {
    if (state.mode == AppThemeMode.system) emit(_resolve(AppThemeMode.system));
  }

  void setMode(AppThemeMode mode) {
    emit(_resolve(mode));
    _themeStore.saveMode(mode);
  }

  void toggleTheme() {
    setMode(isDark ? AppThemeMode.light : AppThemeMode.dark);
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    return super.close();
  }
}
