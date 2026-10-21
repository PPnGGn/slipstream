import 'dart:ui';

import 'package:injectable/injectable.dart';
import 'package:slipstream/core/theme/app_palette.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';

export 'package:slipstream/core/theme/app_palette.dart' show TileHue;

/// The current theme's colors for custom widgets. Reads the palette on every
/// call, so a widget picks up a theme change only when it rebuilds — wrap it
/// in `BlocBuilder<AppThemeCubit, AppThemeState>`.
@LazySingleton()
class AppColors {
  AppColors({required AppThemeCubit themeCubit}) : _themeCubit = themeCubit;

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
