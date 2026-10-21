import 'package:injectable/injectable.dart';
import 'package:slipstream/features/client_identity/data/device_info_api.g.dart';

@module
abstract class DeviceModule {
  @lazySingleton
  DeviceInfoApi get deviceInfoApi => DeviceInfoApi();
}
