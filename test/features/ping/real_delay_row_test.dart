import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/theme/data/theme_store.dart';
import 'package:slipstream/features/ping/data/real_delay_client.dart';
import 'package:slipstream/features/ping/presentation/real_delay_cubit.dart';
import 'package:slipstream/features/ping/presentation/ui/real_delay_row.dart';

import '../../helpers/l10n.dart';

class _Client implements RealDelayClient {
  final calls = <String>[];
  Completer<RealDelayOutcome> answer = Completer();

  @override
  Future<RealDelayOutcome> measure(VpnServer server) {
    calls.add(server.id);
    return answer.future;
  }
}

VpnServer _server(String id, {String config = '{"outbounds": []}'}) =>
    VpnServer(
      id: id,
      subscriptionId: 's',
      countryCode: 'NL',
      title: id,
      configJson: config,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Client client;

  Future<void> pumpRow(
    WidgetTester tester,
    VpnServer server, {
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final theme = AppThemeCubit(
      themeStore: ThemeStore(await SharedPreferences.getInstance()),
    );
    client = _Client();
    await GetIt.I.reset();
    GetIt.I
      ..registerSingleton<AppThemeCubit>(theme)
      ..registerSingleton<AppColors>(AppColors(themeCubit: theme))
      ..registerSingleton<RealDelayCubit>(RealDelayCubit(client));

    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: RealDelayRow(server: server),
          ),
        ),
      ),
    );
  }

  tearDown(() => GetIt.I.reset());

  testWidgets('a tap starts a check of this server and shows the number', (
    tester,
  ) async {
    await pumpRow(tester, _server('a'));

    expect(find.text('Check'), findsOneWidget);
    await tester.tap(find.text('Check'));
    await tester.pump();

    expect(client.calls, ['a']);
    expect(find.text('Checking…'), findsOneWidget);

    client.answer.complete(const RealDelayOutcome.measured(240));
    await tester.pumpAndSettle();

    expect(find.text('240 ms'), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);
  });

  testWidgets('the button does nothing while a check runs', (tester) async {
    await pumpRow(tester, _server('a'));
    await tester.tap(find.text('Check'));
    await tester.pump();

    await tester.tap(find.text('Checking…'), warnIfMissed: false);
    await tester.pump();

    expect(client.calls, ['a']);
    client.answer.complete(const RealDelayOutcome.measured(1));
    await tester.pumpAndSettle();
  });

  testWidgets('a server that cannot work has no row at all', (tester) async {
    await pumpRow(
      tester,
      _server(
        'broken',
        config:
            '{"outbounds":[{"tag":"proxy","streamSettings":{"security":"reality","realitySettings":{}}}]}',
      ),
    );

    expect(find.text('Check'), findsNothing);
    expect(find.text('Real delay'), findsNothing);
  });

  for (final locale in supportedLocales) {
    testWidgets('fits a narrow screen with large text in $locale', (
      tester,
    ) async {
      await pumpRow(tester, _server('a'), locale: locale, textScale: 1.4);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(GestureDetector).last);
      await tester.pump();
      client.answer.complete(const RealDelayOutcome.measured(1234));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
