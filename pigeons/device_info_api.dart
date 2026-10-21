import 'package:pigeon/pigeon.dart';

// VpnApi.g.swift already declares PigeonError in the Runner target, so this
// file's Swift output must not declare it again.
@ConfigurePigeon(
  PigeonOptions(swiftOptions: SwiftOptions(includeErrorClass: false)),
)
class DeviceInfoMessage {
  /// ANDROID_ID / identifierForVendor. Null when the platform has none.
  String? deviceId;
  String os;
  String osVersion;
  String model;
}

@HostApi()
abstract class DeviceInfoApi {
  DeviceInfoMessage getDeviceInfo();
}
