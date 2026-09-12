import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Builds an [http.Client] that tunnels its requests through a loopback HTTP
/// proxy (xray-core's own local `http` inbound) when [proxyPort] is set, or a
/// plain direct client otherwise.
///
/// Why the app needs this at all: the VPN service excludes the app's own
/// package from the tunnel (`addDisallowedApplication` on Android; on iOS the
/// Network Extension is a separate process with no route through its own
/// tunnel). So any in-app request that must ride the *active* connection —
/// [GeoRepository] fetching the geo databases through the currently-connected
/// server, since GitHub is often unreachable from Russia without a VPN — has
/// to be pointed at the core's local proxy, the same inbound panel configs
/// already expose for the OS. [LocalProxyGate] guarantees that inbound exists
/// and reports its port.
///
/// The caller owns the returned client and must `close()` it. Build a fresh
/// one per operation rather than caching: the port is only meaningful while a
/// connection is up and can differ between sessions.
http.Client buildProxiedClient(int? proxyPort) {
  if (proxyPort == null) return http.Client();
  final inner = HttpClient()..findProxy = (_) => 'PROXY 127.0.0.1:$proxyPort';
  return IOClient(inner);
}
