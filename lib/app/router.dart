import 'package:go_router/go_router.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/features/vpn/ui/home_page.dart';
import 'package:slipstream/features/vpn/ui/xray_logs_page.dart';

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(path: '/logs', builder: (context, state) => const XrayLogsPage()),
    GoRoute(
      path: '/logs/flutter',
      builder: (context, state) => TalkerScreen(talker: getIt<Talker>()),
    ),
  ],
);
