import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/theme/app_palette.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';

export 'package:slipstream/core/theme/app_palette.dart' show TileHue;

/// The current theme's colors for custom widgets. Reads the palette on every
/// call, so a widget picks up a theme change only when it rebuilds: either
/// wrap it in `BlocBuilder<AppThemeCubit, AppThemeState>` or get the colors
/// through [AppColors.of].
@LazySingleton()
class AppColors {
  AppColors({required AppThemeCubit themeCubit}) : _themeCubit = themeCubit;

  /// For use in `build`: also subscribes the widget to the app's [Theme], so
  /// it rebuilds on a theme change even when its parent created it as a
  /// `const` widget (Flutter skips rebuilding identical const instances).
  static AppColors of(BuildContext context) {
    Theme.of(context);
    return getIt<AppColors>();
  }

  final AppThemeCubit _themeCubit;

  AppPalette get palette => _themeCubit.state.palette;

  Color get background => palette.background;
  Color get surface => palette.surface;
  Color get surfaceRaised => palette.surfaceRaised;
  Color get border => palette.border;
  Color get inputFill => palette.inputFill;
  Color get chip => palette.chip;
  Color get rowHover => palette.rowHover;
  Color get textPrimary => palette.textPrimary;
  Color get textSecondary => palette.textSecondary;
  Color get textMuted => palette.textMuted;
  Color get primary => palette.primary;
  Color get accentIcon => palette.accentIcon;
  Color get primarySoft => palette.primarySoft;
  Color get selectedRow => palette.selectedRow;
  Color get segment => palette.segment;
  List<Color> get brandGradient => palette.brandGradient;
  Color get ink => palette.ink;
  Color get ok => palette.ok;
  Color get warn => palette.warn;
  Color get danger => palette.danger;
  List<Color> get ringGradient => palette.ringGradient;
  Color get auraOn => palette.auraOn;
  Color get auraOff => palette.auraOff;
  Color get glow => palette.glow;
  Color get connectedLine => palette.connectedLine;
  Color get connectedFill => palette.connectedFill;
  Color get switchKnob => palette.switchKnob;
  Color get switchKnobShadow => palette.switchKnobShadow;
  Color get inverseSurface => palette.inverseSurface;
  Color get onInverseSurface => palette.onInverseSurface;

  Color tileHue(TileHue hue) => palette.tileHue(hue);
}
