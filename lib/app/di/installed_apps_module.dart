import 'package:injectable/injectable.dart';
import 'package:slipstream/features/split_tunnel/data/installed_apps_api.g.dart';

@module
abstract class InstalledAppsModule {
  @lazySingleton
  InstalledAppsApi get installedAppsApi => InstalledAppsApi();
}
