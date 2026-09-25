import 'package:flutter/material.dart';
import 'package:slipstream/app/app.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/features/geo/data/geo_update_service.dart';
import 'package:slipstream/features/ping/presentation/ping_auto_runner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  getIt<GeoUpdateService>().init();
  getIt<PingAutoRunner>().init();
  runApp(const MainApp());
}
