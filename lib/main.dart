import 'package:flutter/material.dart';
import 'package:slipstream/app/app.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/features/geo/data/geo_update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  getIt<GeoUpdateService>().init();
  runApp(const MainApp());
}
