import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:slipstream/app/app_route.dart';
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

// Every route goes through appRoute (not GoRoute): see app_route.dart.
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  routes: [
    appRoute(path: '/', builder: (context, state) => const HomePage()),
    appRoute(path: '/scan', builder: (context, state) => const QrScanPage()),
    appRoute(path: '/logs', builder: (context, state) => const XrayLogsPage()),
    appRoute(
      path: '/logs/flutter',
      builder: (context, state) => TalkerScreen(talker: getIt<Talker>()),
    ),
    appRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
      routes: [
        appRoute(
          path: 'routing',
          builder: (context, state) => const RoutingSettingsPage(),
        ),
        appRoute(
          path: 'ping',
          builder: (context, state) => const PingSettingsPage(),
        ),
        appRoute(
          path: 'subscriptions',
          builder: (context, state) => const SubscriptionSettingsPage(),
        ),
        appRoute(
          path: 'appearance',
          builder: (context, state) => const AppearancePage(),
        ),
        // Not built yet: laid-out pages with inactive controls.
        appRoute(
          path: 'split',
          builder: (context, state) => const SplitTunnelingPage(),
        ),
        appRoute(
          path: 'security',
          builder: (context, state) => const SecurityPage(),
        ),
        appRoute(path: 'dns', builder: (context, state) => const DnsPage()),
        appRoute(
          path: 'backup',
          builder: (context, state) => const BackupPage(),
        ),
        appRoute(
          path: 'assistant',
          builder: (context, state) => const AssistantPage(),
        ),
      ],
    ),
  ],
);
