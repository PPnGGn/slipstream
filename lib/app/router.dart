import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:slipstream/features/appearance/ui/appearance_page.dart';
import 'package:slipstream/features/qr/ui/qr_scan_page.dart';
import 'package:slipstream/features/settings/ui/assistant_page.dart';
import 'package:slipstream/features/settings/ui/backup_page.dart';
import 'package:slipstream/features/settings/ui/dns_page.dart';
import 'package:slipstream/features/settings/ui/ping_settings_page.dart';
import 'package:slipstream/features/settings/ui/security_page.dart';
import 'package:slipstream/features/settings/ui/split_tunneling_page.dart';
import 'package:slipstream/features/settings/ui/subscription_settings_page.dart';
import 'package:slipstream/features/settings/ui/routing_settings_page.dart';
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
    GoRoute(path: '/scan', builder: (context, state) => const QrScanPage()),
    GoRoute(path: '/logs', builder: (context, state) => const XrayLogsPage()),
    GoRoute(
      path: '/logs/flutter',
      builder: (context, state) => TalkerScreen(talker: getIt<Talker>()),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
      routes: [
        GoRoute(
          path: 'routing',
          builder: (context, state) => const RoutingSettingsPage(),
        ),
        GoRoute(
          path: 'ping',
          builder: (context, state) => const PingSettingsPage(),
        ),
        GoRoute(
          path: 'subscriptions',
          builder: (context, state) => const SubscriptionSettingsPage(),
        ),
        GoRoute(
          path: 'appearance',
          builder: (context, state) => const AppearancePage(),
        ),
        // Not built yet: laid-out pages with inactive controls.
        GoRoute(
          path: 'split',
          builder: (context, state) => const SplitTunnelingPage(),
        ),
        GoRoute(
          path: 'security',
          builder: (context, state) => const SecurityPage(),
        ),
        GoRoute(path: 'dns', builder: (context, state) => const DnsPage()),
        GoRoute(
          path: 'backup',
          builder: (context, state) => const BackupPage(),
        ),
        GoRoute(
          path: 'assistant',
          builder: (context, state) => const AssistantPage(),
        ),
      ],
    ),
  ],
);
