import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slipstream/app/app_route.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      routes: [
        appRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/second'),
              child: const Text('first'),
            ),
          ),
          routes: [
            appRoute(
              path: 'second',
              builder: (context, state) =>
                  const Scaffold(body: Text('second')),
            ),
          ],
        ),
      ],
    );
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  }

  testWidgets('pages are MaterialPage, not go_router NoTransitionPage', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('first'));
    await tester.pumpAndSettle();

    final navigator = tester.widget<Navigator>(find.byType(Navigator).first);
    expect(navigator.pages, everyElement(isA<MaterialPage<void>>()));
    expect(navigator.pages, hasLength(2));
  });

  testWidgets('push animates the new page instead of showing it at once', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('first'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final early = tester.getTopLeft(find.text('second')).dx;
    expect(early, greaterThan(0));

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('second')).dx, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('pop goes back to the previous page with an animation', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('first'));
    await tester.pumpAndSettle();

    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('second'), findsOneWidget);
    expect(tester.getTopLeft(find.text('second')).dx, greaterThan(0));

    await tester.pumpAndSettle();
    expect(find.text('second'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
