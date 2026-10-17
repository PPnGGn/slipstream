import 'package:pigeon/pigeon.dart';

enum VpnStatus { disconnected, connecting, connected, disconnecting, error }

class VpnConfigMessage {
  String configJson;
  String? serverId;
  String? title;
  String? geoAssetDir;

  /// True when the config answers the system's DNS itself (the client's own
  /// policy was injected: port 53 on the `socks` inbound goes to `dns-out`).
  /// The tunnel then hands the OS a DNS address inside its own subnet: nothing
  /// listens on 853 there, so Android's automatic Private DNS can't upgrade to
  /// DoT and bypass the config's resolvers. False/null keeps a public resolver
  /// (provider configs route DNS their own way).
  bool? hijackDns;
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

/// The core's loopback HTTP proxy for the app's own requests while the tunnel
/// is up (the app is excluded from its own tunnel). Port and credentials are
/// fresh every session. Carries a password: never log it.
class LocalProxyMessage {
  int port;
  String user;
  String pass;
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

  /// The running session's HTTP proxy, or null while the tunnel is down.
  /// Ask right before use: the value changes every session. iOS always
  /// returns null (the core lives in the Packet Tunnel process).
  LocalProxyMessage? localProxy();
}

/// native -> Flutter
@FlutterApi()
abstract class VpnEventReceiver {
  void onStatusChanged(VpnStatusMessage message);
  void onLog(VpnLogMessage message);
  void onTraffic(VpnTrafficMessage message);
}
