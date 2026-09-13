import 'package:pigeon/pigeon.dart';

enum VpnStatus { disconnected, connecting, connected, disconnecting, error }

class VpnConfigMessage {
  String configJson;
  String? serverId;
  String? title;
  String? geoAssetDir;
}

class VpnStatusMessage {
  VpnStatus status;
  String? error;
  int? connectedAtEpochMs;
}

class VpnLogMessage {
  String level;
  String message;
  String source;
  int timestampMs;
}

class VpnTrafficMessage {
  int uplinkBytes;
  int downlinkBytes;
}

/// Result of a start/stop request.
class VpnResult {
  bool successful;
  String? error;
}

/// Flutter -> native
@HostApi()
abstract class VpnConnection {
  @async
  VpnResult start(VpnConfigMessage config);
  @async
  VpnResult stop();
  @async
  VpnStatusMessage getStatus();
  String? geoAssetDir();

  /// The embedded xray-core version (Android-only).
  String xrayCoreVersion();
}

/// native -> Flutter
@FlutterApi()
abstract class VpnEventReceiver {
  void onStatusChanged(VpnStatusMessage message);
  void onLog(VpnLogMessage message);
  void onTraffic(VpnTrafficMessage message);
}
