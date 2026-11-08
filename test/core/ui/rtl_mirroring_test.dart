import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/theme/data/theme_store.dart';
import 'package:slipstream/core/ui/widgets/mirror_in_rtl.dart';
import 'package:slipstream/core/ui/widgets/page_header.dart';
import 'package:slipstream/core/ui/widgets/wave_switch.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_row.dart';

/// A right-to-left language (Persian) must mirror the layout: what sits at
/// the start of a line sits on its right, and arrows point the other way.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required TextDirection direction,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final cubit = AppThemeCubit(
      themeStore: ThemeStore(await SharedPreferences.getInstance()),
    );
    await GetIt.I.reset();
    GetIt.I.registerSingleton<AppColors>(AppColors(themeCubit: cubit));
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );
  }

  tearDown(() => GetIt.I.reset());

  Finder transformIn(Finder parent) =>
      find.descendant(of: parent, matching: find.byType(Transform));

  group('MirrorInRtl', () {
    testWidgets('leaves the child alone in a left-to-right language', (
      tester,
    ) async {
      await pump(
        tester,
        const MirrorInRtl(child: SizedBox(width: 10, height: 10)),
        direction: TextDirection.ltr,
      );
      expect(transformIn(find.byType(MirrorInRtl)), findsNothing);
    });

    testWidgets('flips the child horizontally in a right-to-left one', (
      tester,
    ) async {
      await pump(
        tester,
        const MirrorInRtl(child: SizedBox(width: 10, height: 10)),
        direction: TextDirection.rtl,
      );
      final transform = tester.widget<Transform>(
        transformIn(find.byType(MirrorInRtl)),
      );
      expect(transform.transform.getRow(0).x, -1);
      expect(transform.transform.getRow(1).y, 1);
    });
  });

  group('WaveSwitch', () {
    double knobOffset(WidgetTester tester) {
      final knob = find.descendant(
        of: find.byType(WaveSwitch),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      return tester.getCenter(knob).dx -
          tester.getCenter(find.byType(WaveSwitch)).dx;
    }

    testWidgets('on: the knob goes to the end of the line', (tester) async {
      await pump(
        tester,
        WaveSwitch(value: true, onChanged: (_) {}),
        direction: TextDirection.ltr,
      );
      await tester.pumpAndSettle();
      expect(knobOffset(tester), greaterThan(0));

      await pump(
        tester,
        WaveSwitch(value: true, onChanged: (_) {}),
        direction: TextDirection.rtl,
      );
      await tester.pumpAndSettle();
      expect(knobOffset(tester), lessThan(0));
    });

    testWidgets('off: the knob stays at the start of the line', (tester) async {
      await pump(
        tester,
        WaveSwitch(value: false, onChanged: (_) {}),
        direction: TextDirection.rtl,
      );
      await tester.pumpAndSettle();
      expect(knobOffset(tester), greaterThan(0));
    });
  });

  testWidgets('the back button of a page is mirrored', (tester) async {
    await pump(
      tester,
      const PageHeader(title: 'x'),
      direction: TextDirection.rtl,
    );
    expect(
      find.descendant(
        of: find.byType(BoxIconButton),
        matching: find.byType(MirrorInRtl),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an action button of a header is not mirrored', (tester) async {
    await pump(
      tester,
      BoxIconButton(iconPath: 'assets/svg/plus.svg', onTap: () {}),
      direction: TextDirection.rtl,
    );
    expect(find.byType(MirrorInRtl), findsNothing);
  });

  testWidgets('the chevron of a settings row is mirrored', (tester) async {
    await pump(
      tester,
      const SettingsRow(title: 'Row', showChevron: true),
      direction: TextDirection.rtl,
    );
    expect(find.byType(MirrorInRtl), findsOneWidget);
  });

  testWidgets('the divider of a settings group is indented from the start', (
    tester,
  ) async {
    await pump(
      tester,
      const SettingsGroup(
        children: [
          SettingsRow(title: 'One'),
          SettingsRow(title: 'Two'),
        ],
      ),
      direction: TextDirection.rtl,
    );
    final padding = tester.widget<Padding>(
      find
          .ancestor(of: find.byType(Divider), matching: find.byType(Padding))
          .first,
    );
    final resolved = padding.padding.resolve(TextDirection.rtl);
    expect(resolved.right, 63);
    expect(resolved.left, 0);
  });
}
