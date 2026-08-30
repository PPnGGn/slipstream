import 'package:injectable/injectable.dart';
import 'package:slipstream/features/update/data/updater_api.g.dart';

@module
abstract class UpdaterModule {
  @lazySingleton
  UpdateInstaller get updateInstaller => UpdateInstaller();
}
