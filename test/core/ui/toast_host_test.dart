import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/core/service/toast/toast_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/theme/data/theme_store.dart';
import 'package:slipstream/core/ui/toast/toast_card.dart';
import 'package:slipstream/core/ui/toast/toast_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ToastCubit cubit;
  var buttonTaps = 0;

  // Mirrors production: the host wraps the navigator inside MaterialApp.builder.
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 600);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final theme = AppThemeCubit(
      themeStore: ThemeStore(await SharedPreferences.getInstance()),
    );
    await GetIt.I.reset();
    GetIt.I.registerSingleton<AppColors>(AppColors(themeCubit: theme));
    cubit = ToastCubit();
    addTearDown(cubit.close);
    buttonTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ToastHost(cubit: cubit, child: child!),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: ElevatedButton(
              onPressed: () => buttonTaps++,
              child: const Text('app button'),
            ),
          ),
        ),
      ),
    );
  }

  // The entrance animation starts on the first frame after show, so the first
  // pump only starts it and the second one runs it to the end.
  Future<void> settleEntrance(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // The test body must end with no timer pending, and tearDown runs after
  // that check: a test that leaves a toast showing closes it here.
  Future<void> finish(WidgetTester tester) async {
    cubit.dismiss();
    await tester.pump(const Duration(milliseconds: 300));
  }

  tearDown(() => GetIt.I.reset());

  testWidgets('nothing is drawn while there is no toast', (tester) async {
    await pumpApp(tester);

    expect(find.byType(ToastCard), findsNothing);
  });

  testWidgets('a shown toast appears over the app', (tester) async {
    await pumpApp(tester);

    cubit.show('Logs copied', subtitle: '14 LINES');
    await tester.pump();

    expect(find.text('Logs copied'), findsOneWidget);
    expect(find.text('14 LINES'), findsOneWidget);
    expect(find.text('app button'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('it fades out once the time is up', (tester) async {
    await pumpApp(tester);

    cubit.show('Done');
    await tester.pump(const Duration(milliseconds: 2199));
    expect(find.byType(ToastCard), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ToastCard), findsNothing);
  });

  testWidgets('a tap on the toast closes it', (tester) async {
    await pumpApp(tester);
    cubit.show('Done');
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byType(ToastCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ToastCard), findsNothing);
    expect(cubit.state, isNull);
  });

  testWidgets('taps outside the toast still reach the app', (tester) async {
    await pumpApp(tester);
    cubit.show('Done');
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('app button'));

    expect(buttonTaps, 1);
    await finish(tester);
  });

  testWidgets('a new toast replaces the old one and restarts the bar', (
    tester,
  ) async {
    await pumpApp(tester);
    cubit.show('First');
    await tester.pump(const Duration(milliseconds: 1500));

    cubit.show('Second');
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    final bar = tester.widget<FractionallySizedBox>(
      find.byKey(const Key('toast-timer')),
    );
    expect(bar.widthFactor, greaterThan(0.95));
    await finish(tester);
  });

  testWidgets('a toast that arrives during the fade-out stays', (
    tester,
  ) async {
    await pumpApp(tester);
    cubit.show('First');
    await tester.pump(const Duration(milliseconds: 400));

    cubit.dismiss();
    await tester.pump(const Duration(milliseconds: 50));
    cubit.show('Second');
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Second'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('it sits 92 px above the bottom edge', (tester) async {
    await pumpApp(tester);
    cubit.show('Done');
    await settleEntrance(tester);

    expect(tester.getBottomLeft(find.byType(ToastCard)).dy, 600 - 92);
    await finish(tester);
  });

  testWidgets('it keeps 14 px at the sides', (tester) async {
    await pumpApp(tester);
    cubit.show('Done');
    await settleEntrance(tester);

    final card = tester.getRect(find.byType(ToastCard));
    expect(card.left, greaterThanOrEqualTo(14));
    expect(card.right, lessThanOrEqualTo(400 - 14));
    await finish(tester);
  });

  testWidgets('with the keyboard open it rides 12 px above the keyboard', (
    tester,
  ) async {
    await pumpApp(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    cubit.show('Done');
    await settleEntrance(tester);

    expect(tester.getBottomLeft(find.byType(ToastCard)).dy, 600 - 300 - 12);
    await finish(tester);
  });
}
