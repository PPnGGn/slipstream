import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/theme/data/theme_store.dart';
import 'package:slipstream/core/ui/widgets/close_circle_button.dart';
import 'package:slipstream/features/help/ui/help_button.dart';
import 'package:slipstream/features/help/ui/help_sheet.dart';
import 'package:slipstream/features/help/ui/help_topic.dart';

import '../../helpers/l10n.dart';

HelpItem _item(String title, {String? tip}) => HelpItem(
  iconPath: AppAssets.bolt,
  hue: TileHue.blue,
  title: title,
  what: 'What $title does.',
  why: 'Why you need $title.',
  tip: tip,
);

const _note = HelpNote(title: 'When it applies', body: 'On reconnect.');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPage(
    WidgetTester tester,
    Widget Function(BuildContext context) opener, {
    Size size = const Size(400, 800),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final theme = AppThemeCubit(
      themeStore: ThemeStore(await SharedPreferences.getInstance()),
    );
    await GetIt.I.reset();
    GetIt.I
      ..registerSingleton<AppThemeCubit>(theme)
      ..registerSingleton<AppColors>(AppColors(themeCubit: theme));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: localizationsDelegates,
        supportedLocales: supportedLocales,
        home: Scaffold(body: Builder(builder: opener)),
      ),
    );
  }

  Future<void> openSheet(
    WidgetTester tester,
    HelpTopic topic, {
    Size size = const Size(400, 800),
  }) async {
    await pumpPage(
      tester,
      (context) => ElevatedButton(
        onPressed: () => showHelpSheet(context, topic),
        child: const Text('open'),
      ),
      size: size,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  tearDown(() async {
    await GetIt.I.reset();
  });

  group('help sheet', () {
    testWidgets('shows the title, the intro and every item', (tester) async {
      await openSheet(
        tester,
        HelpTopic(
          title: 'Routing',
          intro: 'Decides what goes through the VPN.',
          items: [_item('LAN bypass'), _item('Ad blocking')],
        ),
      );

      expect(find.text('Routing'), findsOneWidget);
      expect(find.text('HOW IT WORKS'), findsOneWidget);
      expect(find.text('Decides what goes through the VPN.'), findsOneWidget);
      expect(find.text('LAN bypass'), findsOneWidget);
      expect(find.text('Ad blocking'), findsOneWidget);
    });

    testWidgets('labels what the setting does and why it matters', (
      tester,
    ) async {
      await openSheet(
        tester,
        HelpTopic(
          title: 'Routing',
          intro: 'Intro.',
          items: [_item('LAN bypass'), _item('Ad blocking')],
        ),
      );

      expect(find.text('WHAT IT DOES'), findsNWidgets(2));
      expect(find.text('WHY IT MATTERS'), findsNWidgets(2));
      expect(find.text('What LAN bypass does.'), findsOneWidget);
      expect(find.text('Why you need LAN bypass.'), findsOneWidget);
    });

    testWidgets('draws the tip only for an item that has one', (tester) async {
      await openSheet(
        tester,
        HelpTopic(
          title: 'Routing',
          intro: 'Intro.',
          items: [
            _item('LAN bypass', tip: 'Keep it on.'),
            _item('Other'),
          ],
        ),
      );

      expect(find.text('Keep it on.'), findsOneWidget);
    });

    testWidgets('draws "Good to know" only when there are notes', (
      tester,
    ) async {
      await openSheet(
        tester,
        HelpTopic(
          title: 'Ping',
          intro: 'Intro.',
          items: [_item('A')],
          notes: const [_note],
        ),
      );

      expect(find.text('GOOD TO KNOW'), findsOneWidget);
      expect(find.text('When it applies'), findsOneWidget);
      expect(find.text('On reconnect.'), findsOneWidget);
    });

    testWidgets('has no "Good to know" without notes', (tester) async {
      await openSheet(
        tester,
        HelpTopic(title: 'Ping', intro: 'Intro.', items: [_item('A')]),
      );

      expect(find.text('GOOD TO KNOW'), findsNothing);
    });

    testWidgets('a long topic scrolls on a small screen without overflow', (
      tester,
    ) async {
      await openSheet(
        tester,
        HelpTopic(
          title: 'Long',
          intro: 'Intro.',
          items: [for (var i = 0; i < 12; i++) _item('Item $i', tip: 'Tip $i')],
          notes: const [_note],
        ),
        size: const Size(360, 640),
      );

      await tester.ensureVisible(find.text('On reconnect.'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('On reconnect.'), findsOneWidget);
    });

    testWidgets('the close button closes the sheet', (tester) async {
      await openSheet(
        tester,
        HelpTopic(title: 'Ping', intro: 'Intro.', items: [_item('A')]),
      );

      await tester.tap(find.byType(CloseCircleButton));
      await tester.pumpAndSettle();

      expect(find.text('Intro.'), findsNothing);
    });
  });

  group('help button', () {
    testWidgets('opens the sheet of its topic', (tester) async {
      await pumpPage(
        tester,
        (context) => HelpButton(
          topic: () =>
              HelpTopic(title: 'DNS', intro: 'About DNS.', items: [_item('A')]),
        ),
      );

      expect(find.text('About DNS.'), findsNothing);

      await tester.tap(find.byType(HelpButton));
      await tester.pumpAndSettle();

      expect(find.text('About DNS.'), findsOneWidget);
    });

    testWidgets('builds the topic at tap time, not at build time', (
      tester,
    ) async {
      var allowed = false;
      await pumpPage(
        tester,
        (context) => HelpButton(
          topic: () => HelpTopic(
            title: 'DNS',
            intro: allowed ? 'With fake DNS.' : 'Without fake DNS.',
            items: [_item('A')],
          ),
        ),
      );

      allowed = true;
      await tester.tap(find.byType(HelpButton));
      await tester.pumpAndSettle();

      expect(find.text('With fake DNS.'), findsOneWidget);
    });
  });
}
