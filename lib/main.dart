import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:slipstream/app/app.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/update_service/update_service_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();

  if (Platform.isAndroid) unawaited(getIt<UpdateServiceCubit>().check());

  runApp(const MainApp());
}
