import 'package:flutter/material.dart';
import 'package:slipstream/core/theme/app_colors.dart';

abstract class AppDims {
  static const double horizontalPadding = 16;
  static const double radiusCard = 20;
  static const double radiusControl = 14;
  static const double radiusSheet = 26;
  static const double radiusChip = 100;
  static const double screenInset = 20;
  static const double gapXs = 4,
      gapS = 8,
      gapM = 12,
      gapL = 16,
      gapXl = 20,
      gapXxl = 28;
  static const double hitTarget = 44;
  static const double ringSize = 96; // connect ring in the status card
}

abstract class AppTheme {
  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    bg: AppColorsDark.background,
    surface: AppColorsDark.surface,
    raised: AppColorsDark.surfaceRaised,
    border: AppColorsDark.border,
    inputFill: AppColorsDark.inputFill,
    tx1: AppColorsDark.textPrimary,
    tx2: AppColorsDark.textSecondary,
    tx3: AppColorsDark.textMuted,
    primary: AppColorsDark.primary,
    ink: AppColorsDark.ink,
    danger: AppColorsDark.danger,
    brandGradient: AppColorsDark.brandGradient,
    inverseSurface: AppColorsDark.inverseSurface,
    onInverseSurface: AppColorsDark.onInverseSurface,
  );

  static ThemeData get light => _build(
    brightness: Brightness.light,
    bg: AppColorsLight.background,
    surface: AppColorsLight.surface,
    raised: AppColorsLight.surfaceRaised,
    border: AppColorsLight.border,
    inputFill: AppColorsLight.inputFill,
    tx1: AppColorsLight.textPrimary,
    tx2: AppColorsLight.textSecondary,
    tx3: AppColorsLight.textMuted,
    primary: AppColorsLight.primary,
    ink: AppColorsLight.ink,
    danger: AppColorsLight.danger,
    brandGradient: AppColorsLight.brandGradient,
    inverseSurface: AppColorsLight.inverseSurface,
    onInverseSurface: AppColorsLight.onInverseSurface,
  );

  /// Latency badge color: <80ms ok, <160ms warn, else danger.
  static Color latencyColor(int ms, {required bool dark}) {
    final c = dark ? AppColorsDark.ok : AppColorsLight.ok;
    final w = dark ? AppColorsDark.warn : AppColorsLight.warn;
    final d = dark ? AppColorsDark.danger : AppColorsLight.danger;
    return ms < 80
        ? c
        : ms < 160
        ? w
        : d;
  }

  static TextTheme _textTheme(Color primary, Color secondary, Color muted) =>
      TextTheme(
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: primary,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: primary,
        ),
        titleSmall: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        bodyLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        bodyMedium: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: primary,
        ),
        bodySmall: TextStyle(fontSize: 12.5, color: secondary),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: secondary,
        ),
        labelSmall: TextStyle(fontSize: 11, color: muted),
        // Timers / traffic / pings: JetBrains Mono w600, tabular figures.
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color raised,
    required Color border,
    required Color inputFill,
    required Color tx1,
    required Color tx2,
    required Color tx3,
    required Color primary,
    required Color ink,
    required Color danger,
    required List<Color> brandGradient,
    required Color inverseSurface,
    required Color onInverseSurface,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      surface: surface,
      error: danger,
    ).copyWith(primary: primary, onPrimary: ink, outline: border);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Oswald',
      scaffoldBackgroundColor: bg,
      colorScheme: scheme,
      textTheme: _textTheme(tx1, tx2, tx3),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: tx1,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          fontFamily: 'Oswald',
        ),
        iconTheme: IconThemeData(color: tx2, size: 20),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDims.radiusCard),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        // Brand buttons are a gradient (brandGradient) with ink text.
        // FilledButton can't paint gradients: wrap in Ink/DecoratedBox with
        // brandGradient, or use this solid fallback (gradient's first stop).
        style: FilledButton.styleFrom(
          backgroundColor: brandGradient.first,
          foregroundColor: ink,
          disabledBackgroundColor: raised,
          disabledForegroundColor: tx3,
          minimumSize: const Size(0, 50),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
            fontFamily: 'Oswald',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tx1,
          side: BorderSide(color: border),
          minimumSize: const Size(0, AppDims.hitTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDims.radiusControl),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      iconTheme: IconThemeData(color: tx2),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDims.radiusControl),
          borderSide: BorderSide(color: border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDims.radiusControl),
          borderSide: BorderSide(color: border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDims.radiusControl),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDims.radiusControl),
          borderSide: BorderSide(color: danger, width: 1.5),
        ),
        labelStyle: TextStyle(color: tx2),
        hintStyle: TextStyle(color: tx3),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDims.radiusSheet),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: raised,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDims.radiusControl),
          side: BorderSide(color: border),
        ),
        textStyle: TextStyle(
          color: tx1,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          fontFamily: 'Oswald',
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: inverseSurface,
        contentTextStyle: TextStyle(
          color: onInverseSurface,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          fontFamily: 'Oswald',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDims.radiusChip),
        ),
      ),
      listTileTheme: ListTileThemeData(iconColor: tx2),
    );
  }
}
