import 'package:pigeon/pigeon.dart';

enum VpnStatus { disconnected, connecting, connected, disconnecting, error }

enum VpnSplitMode { proxy, bypass }

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

  VpnSplitMode? splitMode;
  List<String>? splitPackages;
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
  int? memoryBytes;
}

/// The core's HTTP proxy for the app's own requests while the tunnel is up
/// (the app is excluded from its own tunnel). It listens on a Unix socket in
/// the app's private directory, not on a TCP port: a port on the loopback can
/// be found by every other app. Credentials are fresh every session. Carries a
/// password: never log it.
class LocalProxyMessage {
  /// Absolute path of the Unix socket.
  String socket;
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

  /// Whether the OS runs strict Private DNS ("hostname" mode, Android 9+).
  /// Then it never sends ordinary queries to the tunnel's DNS, only the lookup
  /// of the DoT server's own name — which a provider's `dns.hosts` may
  /// deliberately blackhole. Asked before the config is built. iOS: false.
  bool privateDnsStrict();
}

/// native -> Flutter
@FlutterApi()
abstract class VpnEventReceiver {
  void onStatusChanged(VpnStatusMessage message);
  void onLog(VpnLogMessage message);
  void onTraffic(VpnTrafficMessage message);
}
