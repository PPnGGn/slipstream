import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/app_palette.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/theme/data/theme_store.dart';
import 'package:slipstream/core/ui/widgets/close_circle_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpButton(
    WidgetTester tester,
    AppThemeMode mode, {
    bool overCamera = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final cubit = AppThemeCubit(
      themeStore: ThemeStore(await SharedPreferences.getInstance()),
    )..setMode(mode);
    await GetIt.I.reset();
    GetIt.I.registerSingleton<AppColors>(AppColors(themeCubit: cubit));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CloseCircleButton(onPressed: () {}, overCamera: overCamera),
        ),
      ),
    );
  }

  Color? fill(WidgetTester tester) => tester
      .widget<IconButton>(find.byType(IconButton))
      .style
      ?.backgroundColor
      ?.resolve({});

  ColorFilter? glyph(WidgetTester tester) =>
      tester.widget<SvgPicture>(find.byType(SvgPicture)).colorFilter;

  tearDown(() => GetIt.I.reset());

  testWidgets('in a sheet it takes its colors from the theme', (tester) async {
    for (final (mode, palette) in [
      (AppThemeMode.light, AppPalette.light),
      (AppThemeMode.dark, AppPalette.dark),
      (AppThemeMode.phosphor, AppPalette.phosphor),
    ]) {
      await pumpButton(tester, mode);
      expect(fill(tester), palette.chip, reason: '$mode circle');
      expect(
        glyph(tester),
        ColorFilter.mode(palette.textSecondary, BlendMode.srcIn),
        reason: '$mode ×',
      );
    }
  });

  testWidgets('over the camera it stays white on a dark circle', (
    tester,
  ) async {
    await pumpButton(tester, AppThemeMode.light, overCamera: true);
    expect(fill(tester), Colors.black54);
    expect(
      glyph(tester),
      const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );
  });
}
