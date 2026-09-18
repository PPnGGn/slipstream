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

  /// xray-core's own memory footprint, sampled on the same 1 Hz tick as the
  /// counters above. Android: `runtime.MemStats.Sys` from the embedded Go
  /// runtime — isolated from the surrounding Flutter/Android process, which
  /// carries its own (much larger) Skia/engine overhead. iOS: `phys_footprint`
  /// of the whole PacketTunnel extension process, whose jetsam budget is
  /// ~50 MB — there the extension has nothing else heavy resident, so the
  /// whole-process number is already a clean proxy for xray-core's own cost.
  /// Null if the sample failed.
  int? memoryBytes;
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
