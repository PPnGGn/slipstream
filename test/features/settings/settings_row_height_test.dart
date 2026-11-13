import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/theme/data/theme_store.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_row.dart';

/// A row whose subtitle changes with its setting (Kill switch, Fragment and
/// Noise show one text while off and another while on) must not change its
/// height with the text: the page would jump under the finger at every switch.
/// That has to hold at the phone's font size too, not only at the default one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(
    WidgetTester tester,
    List<Widget> rows, {
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final cubit = AppThemeCubit(
      themeStore: ThemeStore(await SharedPreferences.getInstance()),
    );
    await GetIt.I.reset();
    GetIt.I.registerSingleton<AppColors>(AppColors(themeCubit: cubit));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 340, child: Column(children: rows)),
          ),
        ),
      ),
    );
  }

  tearDown(() => GetIt.I.reset());

  double heightOf(WidgetTester tester, int index) =>
      tester.getSize(find.byType(SettingsRow).at(index)).height;

  const short = 'Off';
  const twoLines =
      'Off · a lost tunnel just closes the VPN and nothing else happens';
  const long =
      'Off · a subtitle that goes on and on and on, so that it needs far '
      'more than two lines of a narrow row, in any language';

  List<Widget> rows() => const [
    SettingsRow(
      title: 'A',
      subtitle: short,
      switchValue: false,
      subtitleMaxLines: 2,
    ),
    SettingsRow(
      title: 'B',
      subtitle: twoLines,
      switchValue: true,
      subtitleMaxLines: 2,
    ),
    SettingsRow(
      title: 'C',
      subtitle: long,
      switchValue: false,
      subtitleMaxLines: 2,
    ),
  ];

  testWidgets('rows that limit the subtitle keep one height for any text', (
    tester,
  ) async {
    await pump(tester, rows());

    expect(heightOf(tester, 1), closeTo(heightOf(tester, 0), 0.01));
    expect(heightOf(tester, 2), closeTo(heightOf(tester, 0), 0.01));
  });

  testWidgets('and keep it at a larger system font', (tester) async {
    await pump(tester, rows(), textScale: 1.5);

    expect(heightOf(tester, 1), closeTo(heightOf(tester, 0), 0.01));
    expect(heightOf(tester, 2), closeTo(heightOf(tester, 0), 0.01));
  });

  testWidgets('a larger font makes the row taller, not the text overflow', (
    tester,
  ) async {
    await pump(tester, rows());
    final normal = heightOf(tester, 0);
    await pump(tester, rows(), textScale: 1.5);

    expect(heightOf(tester, 0), greaterThan(normal));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a subtitle over the limit is cut, not allowed to grow the row', (
    tester,
  ) async {
    await pump(tester, rows());

    final subtitle = tester.widget<Text>(find.text(long));

    expect(subtitle.maxLines, equals(2));
    expect(subtitle.overflow, equals(TextOverflow.ellipsis));
  });

  testWidgets('a row with no limit is as it was: 60, and as tall as its text', (
    tester,
  ) async {
    await pump(tester, const [
      SettingsRow(title: 'A'),
      SettingsRow(title: 'B', subtitle: long),
    ]);

    expect(heightOf(tester, 0), equals(60));
    expect(heightOf(tester, 1), greaterThan(80));
  });
}
