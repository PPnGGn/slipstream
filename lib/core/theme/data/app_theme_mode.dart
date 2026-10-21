import 'dart:ui';

import 'package:slipstream/core/theme/app_palette.dart';

enum AppThemeMode { light, dark, phosphor }

class AppThemeState {
  const AppThemeState({required this.mode});

  final AppThemeMode mode;

  AppPalette get palette => switch (mode) {
    AppThemeMode.light => AppPalette.light,
    AppThemeMode.dark => AppPalette.dark,
    AppThemeMode.phosphor => AppPalette.phosphor,
  };

  /// Phosphor is a dark theme too.
  bool get isDark => palette.brightness == Brightness.dark;

  @override
  bool operator ==(Object other) =>
      other is AppThemeState && other.mode == mode;

  @override
  int get hashCode => mode.hashCode;
}
