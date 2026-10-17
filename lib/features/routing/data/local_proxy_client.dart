import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';

/// Asks the core for the loopback HTTP proxy of the running session.
///
/// The core picks a fresh port and password every session and keeps them in
/// Go; nothing is cached here. Call [current] right before each operation that
/// needs it, never earlier: on Android `VpnConnection.start` returns before the
/// core is actually up, and the value is gone as soon as the tunnel stops.
@lazySingleton
class LocalProxyProvider {
  LocalProxyProvider(this._connection, this._talker);

  final VpnConnection _connection;
  final Talker _talker;

  /// The proxy, or null while no tunnel is up (and always on iOS, where the
  /// app is routed through the system tunnel anyway). Never log the result:
  /// it carries the proxy password.
  Future<LocalProxyMessage?> current() async {
    try {
      final proxy = await _connection.localProxy();
      _talker.debug(
        proxy == null
            ? 'LocalProxy: no tunnel, going direct'
            : 'LocalProxy: routing through the tunnel',
      );
      return proxy;
    } catch (e) {
      // e is a platform/channel error, it never contains the credentials.
      _talker.warning('LocalProxy: lookup failed, going direct: $e');
      return null;
    }
  }
}

/// `HttpClient.findProxy` directive for [proxy]. Credentials in the
/// `user:pass@` form make Dart send `Proxy-Authorization` itself, for plain
/// requests and for the `CONNECT` that HTTPS goes through. The core generates
/// them as hex, so they never need escaping here.
String proxyDirective(LocalProxyMessage proxy) =>
    'PROXY ${proxy.user}:${proxy.pass}@127.0.0.1:${proxy.port}';

/// Builds an [http.Client] that tunnels its requests through the core's
/// loopback HTTP proxy when [proxy] is set, or a plain direct client otherwise.
///
/// Why the app needs this at all: the VPN service excludes the app's own
/// package from the tunnel (`addDisallowedApplication` on Android). So any
/// in-app request that must ride the *active* connection — [GeoRepository]
/// fetching the geo databases through the currently-connected server, since
/// GitHub is often unreachable from Russia without a VPN — has to be pointed
/// at the core's local proxy. Get [proxy] from [LocalProxyProvider.current].
///
/// The caller owns the returned client and must `close()` it. Build a fresh
/// one per operation rather than caching: port and password change every
/// session.
http.Client buildProxiedClient(LocalProxyMessage? proxy) {
  if (proxy == null) return http.Client();
  final inner = HttpClient()..findProxy = (_) => proxyDirective(proxy);
  return IOClient(inner);
}
