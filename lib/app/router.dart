import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:slipstream/features/settings/ui/settings_page.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/features/vpn/ui/home_page.dart';
import 'package:slipstream/features/vpn/ui/xray_logs_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(path: '/logs', builder: (context, state) => const XrayLogsPage()),
    GoRoute(
      path: '/logs/flutter',
      builder: (context, state) => TalkerScreen(talker: getIt<Talker>()),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
  ],
);
