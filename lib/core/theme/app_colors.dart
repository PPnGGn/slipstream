import 'dart:ui';

import 'package:injectable/injectable.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';

@LazySingleton()
class AppColors {
  AppColors({required AppThemeCubit themeCubit}) : _themeCubit = themeCubit;

  final AppThemeCubit _themeCubit;

  Color get background =>
      _themeCubit.isDark ? AppColorsDark.background : AppColorsLight.background;
  Color get surface =>
      _themeCubit.isDark ? AppColorsDark.surface : AppColorsLight.surface;
  Color get surfaceRaised => _themeCubit.isDark
      ? AppColorsDark.surfaceRaised
      : AppColorsLight.surfaceRaised;
  Color get border =>
      _themeCubit.isDark ? AppColorsDark.border : AppColorsLight.border;
  Color get inputFill =>
      _themeCubit.isDark ? AppColorsDark.inputFill : AppColorsLight.inputFill;
  Color get chip =>
      _themeCubit.isDark ? AppColorsDark.chip : AppColorsLight.chip;
  Color get textPrimary => _themeCubit.isDark
      ? AppColorsDark.textPrimary
      : AppColorsLight.textPrimary;
  Color get textSecondary => _themeCubit.isDark
      ? AppColorsDark.textSecondary
      : AppColorsLight.textSecondary;
  Color get textMuted =>
      _themeCubit.isDark ? AppColorsDark.textMuted : AppColorsLight.textMuted;
  Color get primary =>
      _themeCubit.isDark ? AppColorsDark.primary : AppColorsLight.primary;
  Color get ink => _themeCubit.isDark ? AppColorsDark.ink : AppColorsLight.ink;
  Color get ok => _themeCubit.isDark ? AppColorsDark.ok : AppColorsLight.ok;
  Color get warn =>
      _themeCubit.isDark ? AppColorsDark.warn : AppColorsLight.warn;
  Color get danger =>
      _themeCubit.isDark ? AppColorsDark.danger : AppColorsLight.danger;
  List<Color> get brandGradient => _themeCubit.isDark
      ? AppColorsDark.brandGradient
      : AppColorsLight.brandGradient;
  List<Color> get ringGradient => _themeCubit.isDark
      ? AppColorsDark.ringGradient
      : AppColorsLight.ringGradient;
  Color get switchKnob =>
      _themeCubit.isDark ? AppColorsDark.switchKnob : AppColorsLight.switchKnob;
  Color get switchKnobShadow => _themeCubit.isDark
      ? AppColorsDark.switchKnobShadow
      : AppColorsLight.switchKnobShadow;
  Color get inverseSurface => _themeCubit.isDark
      ? AppColorsDark.inverseSurface
      : AppColorsLight.inverseSurface;
  Color get onInverseSurface => _themeCubit.isDark
      ? AppColorsDark.onInverseSurface
      : AppColorsLight.onInverseSurface;
}

abstract class AppColorsDark {
  static const background = Color(0xFF22222E);
  static const surface = Color(0xFF2B2C3E);
  static const surfaceRaised = Color(0xFF333450);
  static const border = Color(0xFF3E3F5C);
  static const inputFill = Color(0xFF1D1D28);
  static const chip = Color(0xFF393A5A);
  static const textPrimary = Color(0xFFE9E9E9);
  static const textSecondary = Color(0xFFADA9BA);
  static const textMuted = Color(0xFF706F8E);
  static const primary = Color(0xFFADB5D3);
  static const ink = Color(0xFF2E2F45); // text on brand gradient
  static const ok = Color(0xFF8CC3A8);
  static const warn = Color(0xFFD9B36A);
  static const danger = Color(0xFFD98A9C);
  static const brandGradient = [Color(0xFFADB5D3), Color(0xFFB0C3C9)];
  static const ringGradient = [
    Color(0xFFADB5D3),
    Color(0xFFB0C3C9),
    Color(0xFF8CC3A8),
  ];
  // WaveSwitch knob.
  static const switchKnob = Color(0xFFFFFFFF);
  static const switchKnobShadow = Color(0x4D14141F);
  // Inverse surface: SnackBar background/foreground (opposite brightness).
  static const inverseSurface = textPrimary;
  static const onInverseSurface = ink;
}

abstract class AppColorsLight {
  static const background = Color(0xFFF9F3F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceRaised = Color(0xFFFFFFFF);
  static const border = Color(0xFFE1DBE5);
  static const inputFill = Color(0xFFF7F2F5);
  static const chip = Color(0xFFEFEAF0);
  static const textPrimary = Color(0xFF2E2F45);
  static const textSecondary = Color(0xFF706F8E);
  static const textMuted = Color(0xFFADA9BA);
  static const primary = Color(0xFF8B93BF); // darkened #ADB5D3 for contrast
  static const ink = Color(0xFF2E2F45);
  static const ok = Color(0xFF55917A);
  static const warn = Color(0xFFA97F35);
  static const danger = Color(0xFFB75D75);
  static const brandGradient = [Color(0xFFADB5D3), Color(0xFFB0C3C9)];
  static const ringGradient = [
    Color(0xFFADB5D3),
    Color(0xFF8B93BF),
    Color(0xFF55917A),
  ];
  // WaveSwitch knob.
  static const switchKnob = Color(0xFFFFFFFF);
  static const switchKnobShadow = Color(0x4D14141F);
  // Inverse surface: SnackBar background/foreground (opposite brightness).
  static const inverseSurface = ink;
  static const onInverseSurface = background;
}
