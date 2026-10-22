import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:slipstream/app/app.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/features/geo/data/geo_update_service.dart';
import 'package:slipstream/features/ping/presentation/ping_auto_runner.dart';
import 'package:slipstream/features/subscriptions/cubit/subscription_auto_updater.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/subscription_sync_job.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/sync_api.g.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  getIt<GeoUpdateService>().init();
  getIt<PingAutoRunner>().init();
  getIt<SubscriptionAutoUpdater>().init();
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
