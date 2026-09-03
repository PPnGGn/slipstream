import 'dart:io';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:slipstream/features/update/data/updater_api.g.dart';

@module
abstract class UpdaterModule {
  @lazySingleton
  UpdateInstaller get updateInstaller => UpdateInstaller();

  @preResolve
  @singleton
  @Named('updatesDir')
  Future<Directory> get updatesDir async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}updates');
    await dir.create(recursive: true);
    return dir;
  }
}
