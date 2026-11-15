import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/theme/data/theme_store.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_row.dart';

/// Every settings row is 56 logical pixels tall, whatever its subtitle says:
/// no empty space under a short text, and no jump of the page when a subtitle
/// changes with its setting (Kill switch, Fragment and Noise show one text
/// while off and another while on). A longer text is cut to one line.
/// A larger system font makes every row taller by the same amount, and the text
/// never overflows.
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
  const long =
      'Off · a subtitle that goes on and on and on, so that it needs far '
      'more than one line of a narrow row, in any language';

  List<Widget> rows() => const [
    SettingsRow(title: 'No subtitle'),
    SettingsRow(title: 'Short', subtitle: short, switchValue: false),
    SettingsRow(title: 'Long', subtitle: long, switchValue: true),
    SettingsRow(title: 'Chevron', subtitle: short, showChevron: true),
    SettingsRow(
      title: 'Value',
      subtitle: long,
      value: 'Dark',
      showChevron: true,
    ),
  ];

  testWidgets('every row is 56, with a short, a long or no subtitle', (
    tester,
  ) async {
    await pump(tester, rows());

    for (var i = 0; i < rows().length; i++) {
      expect(heightOf(tester, i), equals(56), reason: 'row $i');
    }
  });

  testWidgets('a subtitle over one line is cut, not allowed to grow the row', (
    tester,
  ) async {
    await pump(tester, rows());

    final subtitle = tester.widget<Text>(find.text(long).first);

    expect(subtitle.maxLines, equals(1));
    expect(subtitle.overflow, equals(TextOverflow.ellipsis));
  });

  testWidgets('a larger system font keeps the rows equal, and nothing overflows', (
    tester,
  ) async {
    await pump(tester, rows(), textScale: 1.5);

    for (var i = 1; i < rows().length; i++) {
      expect(heightOf(tester, i), closeTo(heightOf(tester, 1), 0.01));
    }
    expect(heightOf(tester, 0), greaterThanOrEqualTo(56));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a footer comes under the 56, it does not stretch the row', (
    tester,
  ) async {
    await pump(tester, const [
      SettingsRow(
        title: 'With footer',
        subtitle: short,
        footer: SizedBox(height: 30),
      ),
    ]);

    // 56 for the row, the footer's 30 and its 12 below.
    expect(heightOf(tester, 0), equals(56 + 30 + 12));
  });
}
