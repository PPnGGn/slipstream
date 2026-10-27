import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/toast/toast_cubit.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/theme/data/theme_store.dart';
import 'package:slipstream/core/ui/widgets/page_header.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';
import 'package:slipstream/features/vpn/data/xray_log_store.dart';
import 'package:slipstream/features/vpn/ui/xray_logs_page.dart';

import '../subscriptions/data/subscription_fakes.dart';

VpnLogMessage _log(String level, String message, {int second = 0}) =>
    VpnLogMessage(
      level: level,
      message: message,
      source: 'tun2socks',
      timestampMs: DateTime(2026, 10, 27, 0, 11, second).millisecondsSinceEpoch,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late XrayLogStore store;
  late FakeVpnCubit vpn;
  late ToastCubit toasts;
  String? clipboard;

  Future<void> openPage(
    WidgetTester tester,
    List<VpnLogMessage> logs,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final theme = AppThemeCubit(
      themeStore: ThemeStore(await SharedPreferences.getInstance()),
    );
    store = XrayLogStore();
    vpn = FakeVpnCubit();
    toasts = ToastCubit();
    await GetIt.I.reset();
    GetIt.I
      ..registerSingleton<AppColors>(AppColors(themeCubit: theme))
      ..registerSingleton<XrayLogStore>(store)
      ..registerSingleton<VpnServiceCubit>(vpn)
      ..registerSingleton<ToastCubit>(toasts);
    logs.forEach(store.add);

    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        });

    await tester.pumpWidget(const MaterialApp(home: XrayLogsPage()));
    // The store's own 200 ms flush timer must not outlive the test.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  // The test body must end with no timer pending (checked before tearDown).
  Future<void> finish(WidgetTester tester) async {
    toasts.dismiss();
    store.clear();
    await tester.pumpAndSettle();
  }

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await toasts.close();
    await GetIt.I.reset();
  });

  final three = [
    _log('info', 'started', second: 1),
    _log('warning', 'dns timeout', second: 2),
    _log('error', 'conn refused', second: 3),
  ];

  Finder chip(String name) => find.byKey(ValueKey('log-filter-$name'));

  testWidgets('draws time, level and message of every line', (tester) async {
    await openPage(tester, three);

    expect(find.text('00:11:01'), findsOneWidget);
    expect(find.text('started'), findsOneWidget);
    expect(find.text('dns timeout'), findsOneWidget);
    expect(find.text('conn refused'), findsOneWidget);
    // The level of the line, not only the chip with the same word.
    expect(find.text('WARN'), findsNWidgets(2));
    expect(find.text('ERROR'), findsNWidgets(2));
    await finish(tester);
  });

  testWidgets('a line is two columns: level over time, then the message', (
    tester,
  ) async {
    await openPage(tester, three);

    // The second line of `three`: the warning.
    final level = tester.getTopLeft(find.byKey(const Key('log-level')).at(1));
    final time = find.text('00:11:02');
    final message = tester.getTopLeft(find.text('dns timeout'));

    // Same left edge, the level above the time.
    expect(level.dx, tester.getTopLeft(time).dx);
    expect(level.dy, lessThan(tester.getTopLeft(time).dy));
    // The left column is only as wide as the time, the message follows it.
    expect(message.dx, tester.getTopRight(time).dx + 8);
    // The message starts level with the tag, not below it.
    expect(message.dy, level.dy);
    await finish(tester);
  });

  testWidgets('does not draw the source of a line', (tester) async {
    await openPage(tester, three);

    expect(find.textContaining('tun2socks'), findsNothing);
    await finish(tester);
  });

  testWidgets('has the title and a Copy button, but no way to clear', (
    tester,
  ) async {
    await openPage(tester, three);

    expect(find.text('Xray core logs'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    // Back and the Flutter logs: no trash can, no jump-to-bottom arrow.
    expect(find.byType(BoxIconButton), findsNWidgets(2));
    await finish(tester);
  });

  testWidgets('the status line counts lines and follows the tunnel', (
    tester,
  ) async {
    await openPage(tester, three);
    expect(find.text('FOLLOWING · 3 LINES · TUNNEL DOWN'), findsOneWidget);

    vpn.push(
      VpnState.connected(
        const VpnServer(
          id: 'a',
          subscriptionId: 's',
          countryCode: 'NL',
          title: 'A',
          configJson: '{}',
        ),
        connectedAt: DateTime(2026),
      ),
    );
    // The fake delivers the state through a stream: one pump for the event,
    // one for the rebuild it causes.
    await tester.pump();
    await tester.pump();

    expect(find.text('FOLLOWING · 3 LINES · TUNNEL UP'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a filter chip keeps only its level and the count follows', (
    tester,
  ) async {
    await openPage(tester, three);

    await tester.tap(chip('warn'));
    await tester.pump();

    expect(find.text('dns timeout'), findsOneWidget);
    expect(find.text('started'), findsNothing);
    expect(find.text('conn refused'), findsNothing);
    expect(find.text('FOLLOWING · 1 LINE · TUNNEL DOWN'), findsOneWidget);

    await tester.tap(chip('all'));
    await tester.pump();

    expect(find.text('started'), findsOneWidget);
    expect(find.text('FOLLOWING · 3 LINES · TUNNEL DOWN'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('with no logs at all it says where they come from', (
    tester,
  ) async {
    await openPage(tester, const []);

    expect(find.text('Logs appear while the tunnel runs'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('with logs hidden by the filter it names the level', (
    tester,
  ) async {
    await openPage(tester, [_log('info', 'started')]);

    await tester.tap(chip('error'));
    await tester.pump();

    expect(find.text('No ERROR lines'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Copy puts every line on the clipboard and confirms', (
    tester,
  ) async {
    await openPage(tester, three);

    await tester.tap(find.text('Copy'));
    await tester.pump();

    expect(
      clipboard,
      '00:11:01 [INFO] started · tun2socks\n'
      '00:11:02 [WARN] dns timeout · tun2socks\n'
      '00:11:03 [ERROR] conn refused · tun2socks',
    );
    expect(toasts.state!.title, 'Logs copied');
    expect(toasts.state!.subtitle, '3 LINES · PLAIN TEXT');
    await finish(tester);
  });

  testWidgets('Copy takes only the lines the filter shows', (tester) async {
    await openPage(tester, three);
    await tester.tap(chip('error'));
    await tester.pump();

    await tester.tap(find.text('Copy'));
    await tester.pump();

    expect(clipboard, '00:11:03 [ERROR] conn refused · tun2socks');
    expect(toasts.state!.subtitle, '1 LINE · PLAIN TEXT');
    await finish(tester);
  });

  testWidgets('Copy with no logs copies nothing and says so', (tester) async {
    await openPage(tester, const []);

    await tester.tap(find.text('Copy'));
    await tester.pump();

    expect(clipboard, isNull);
    expect(toasts.state!.title, 'Nothing to copy');
    await finish(tester);
  });

  group('with a log longer than the screen', () {
    final many = [
      for (var i = 0; i < 80; i++) _log('info', 'line $i', second: i % 60),
    ];

    ScrollPosition position(WidgetTester tester) =>
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;

    testWidgets('it starts at the newest line, following', (tester) async {
      await openPage(tester, many);
      await tester.pumpAndSettle();

      expect(position(tester).pixels, position(tester).maxScrollExtent);
      expect(find.text('FOLLOWING · 80 LINES · TUNNEL DOWN'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('scrolling up pauses it', (tester) async {
      await openPage(tester, many);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(find.text('PAUSED · 80 LINES · TUNNEL DOWN'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a new line scrolls into view while it follows', (
      tester,
    ) async {
      await openPage(tester, many);
      await tester.pumpAndSettle();

      store.add(_log('info', 'brand new'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('brand new'), findsOneWidget);
      expect(position(tester).pixels, position(tester).maxScrollExtent);
      await finish(tester);
    });

    testWidgets('a new line does not drag the view back once paused', (
      tester,
    ) async {
      await openPage(tester, many);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();
      final before = position(tester).pixels;

      store.add(_log('info', 'brand new'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(position(tester).pixels, before);
      await finish(tester);
    });
  });
}
