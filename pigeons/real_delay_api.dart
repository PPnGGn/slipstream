import 'package:pigeon/pigeon.dart';

/// What the core needs to measure one server (Android only, like NativePrefsApi).
class RealDelayRequest {
  RealDelayRequest({
    required this.configJson,
    required this.geoAssetDir,
    required this.url,
    required this.timeoutMs,
  });

  /// The full client config of the server, as the tunnel would start it. It
  /// carries the server's credentials: never log it.
  String configJson;

  /// The folder of the geo bases, which the rules of the config read.
  String geoAssetDir;

  /// The address the request goes to through the server.
  String url;

  /// One limit for the whole measurement, the start of xray included.
  int timeoutMs;
}

/// Exactly one of the two is set: the time in milliseconds, or why there is
/// none. The reason is the core's own text and is for logs, not for the user.
class RealDelayResult {
  RealDelayResult({this.latencyMs, this.error});

  int? latencyMs;
  String? error;
}

@HostApi()
abstract class RealDelayApi {
  /// Sends a request through the server and says how long it took. Runs off
  /// the main thread and answers when it is over, up to `timeoutMs` later.
  @async
  RealDelayResult measure(RealDelayRequest request);
}
