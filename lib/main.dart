import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:slipstream/app/app.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/features/auto_connect/presentation/auto_connect_runner.dart';
import 'package:slipstream/features/launch_sync/presentation/launch_sync_runner.dart';
import 'package:slipstream/features/geo/data/geo_update_service.dart';
import 'package:slipstream/features/native_prefs/presentation/native_prefs_runner.dart';
import 'package:slipstream/features/ping/presentation/ping_auto_runner.dart';
import 'package:slipstream/features/subscriptions/cubit/subscription_auto_updater.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/subscription_sync_job.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/sync_api.g.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  getIt<GeoUpdateService>().init();
  getIt<PingAutoRunner>().init();
  // Tells the VPN notification and the tile (Kotlin) which language to use.
  getIt<NativePrefsRunner>().init();
  getIt<SubscriptionAutoUpdater>().init();
  // Not awaited: it waits for the subscriptions and the VPN status, the first
  // frame must not.
  unawaited(getIt<AutoConnectRunner>().init());
  // Keeps the tile's saved launch in step with the settings (Android). Same
  // reason not to await: it waits for the subscriptions and the VPN status.
  unawaited(getIt<LaunchSyncRunner>().init());
  runApp(const MainApp());
}

/// Entry point of the headless engine the Android background job starts
/// (SubscriptionSyncWorker.kt) while the UI is not running: refreshes the
/// subscriptions that are due, reports back and lets the engine go.
@pragma('vm:entry-point')
Future<void> subscriptionSyncMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  var ok = false;
  try {
    await configureDependencies();
    ok = await getIt<SubscriptionSyncJob>().run();
  } catch (e, st) {
    debugPrint('Sync: background run failed: $e\n$st');
  } finally {
    await BackgroundTaskHost().finished(ok);
  }
}
