import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';

/// Asks the core for the HTTP proxy of the running session (a Unix socket).
///
/// The core picks a fresh password every session and keeps it in Go; nothing
/// is cached here. Call [current] right before each operation that
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
///
/// The host and port are only there because the directive needs them; where the
/// connection goes is decided by [buildProxiedClient], which connects to the
/// socket of [proxy] whatever they say.
String proxyDirective(LocalProxyMessage proxy) =>
    'PROXY ${proxy.user}:${proxy.pass}@localhost:1';

/// Builds an [http.Client] that tunnels its requests through the core's HTTP
/// proxy when [proxy] is set, or a plain direct client otherwise.
///
/// The proxy listens on a Unix socket, not on a TCP port: a port on the
/// loopback can be found by every other app on the phone, a socket in the
/// app's private directory cannot. Dart speaks to a proxy as usual (absolute
/// URI, `CONNECT` for HTTPS); only the connection to it is made to the socket.
///
/// Why the app needs this at all: the VPN service excludes the app's own
/// package from the tunnel (`addDisallowedApplication` on Android). So any
/// in-app request that must ride the *active* connection — [GeoRepository]
/// fetching the geo databases through the currently-connected server, since
/// GitHub is often unreachable from Russia without a VPN — has to be pointed
/// at the core's local proxy. Get [proxy] from [LocalProxyProvider.current].
///
/// The caller owns the returned client and must `close()` it. Build a fresh
/// one per operation rather than caching: socket and password change every
/// session.
///
/// A client that lives long (a download of several files is one) can outlive
/// the session it was built for: the core restarts, the socket is the same, the
/// password is a new one, and the proxy answers 407 to the old. With [refresh]
/// (the provider's `current`) such a request is repeated once with the password
/// the core reports now. Only a request that is safe to send twice (GET, HEAD)
/// is repeated, and only if the password did change, so a 407 that has another
/// cause is returned as it is.
http.Client buildProxiedClient(
  LocalProxyMessage? proxy, {
  Future<LocalProxyMessage?> Function()? refresh,
}) {
  if (proxy == null) return http.Client();
  if (refresh == null) return _proxiedIoClient(proxy);
  return _RefreshingProxyClient(proxy, refresh);
}

/// The client factory for requests that may span a restart of the core, see
/// [buildProxiedClient].
http.Client Function(LocalProxyMessage?) refreshingProxyClientFactory(
  LocalProxyProvider provider,
) =>
    (proxy) => buildProxiedClient(proxy, refresh: provider.current);

http.Client _proxiedIoClient(LocalProxyMessage proxy) {
  final socket = InternetAddress(proxy.socket, type: InternetAddressType.unix);
  final directive = proxyDirective(proxy);
  final inner = HttpClient();
  // Separate statements, not one cascade: the body of an arrow function runs on
  // to the end of the expression and would swallow the next `..`.
  inner.findProxy = (_) => directive;
  inner.connectionFactory = (uri, proxyHost, proxyPort) =>
      Socket.startConnect(socket, 0);
  return IOClient(inner);
}

bool _sameProxy(LocalProxyMessage a, LocalProxyMessage b) =>
    a.socket == b.socket && a.user == b.user && a.pass == b.pass;

/// A client for the proxy of one session that follows the core into the next:
/// when a request fails with the password of the session before, it asks for
/// the one the core has now and sends the request again, once.
class _RefreshingProxyClient extends http.BaseClient {
  _RefreshingProxyClient(this._proxy, this._refresh)
    : _inner = _proxiedIoClient(_proxy);

  LocalProxyMessage _proxy;
  http.Client _inner;
  final Future<LocalProxyMessage?> Function() _refresh;

  /// Clients of passwords that are gone. Not closed at once: a request that
  /// still reads from one must not be cut short by another one's retry.
  final _retired = <http.Client>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // A request can be sent only once, so the copy is made before it is.
    final again = _repeatable(request);
    final used = _proxy;

    http.StreamedResponse response;
    try {
      response = await _inner.send(request);
    } on Exception {
      // The CONNECT of an HTTPS request that got the 407 ends up here, as an
      // exception without a status code to look at: so the test is not the
      // text of the error but whether the password has changed.
      if (again == null || !await _adopt(used)) rethrow;
      return _inner.send(again);
    }
    if (response.statusCode != 407 || again == null) return response;
    if (!await _adopt(used)) return response;
    await response.stream.drain<void>(); // give the connection back
    return _inner.send(again);
  }

  /// Takes the password the core reports now, if it is not the one that just
  /// failed. True when there is something new to try, whoever fetched it.
  Future<bool> _adopt(LocalProxyMessage used) async {
    final fresh = await _refresh();
    if (fresh != null && !_sameProxy(fresh, _proxy)) {
      _retired.add(_inner);
      _proxy = fresh;
      _inner = _proxiedIoClient(fresh);
    }
    return !_sameProxy(_proxy, used);
  }

  /// A copy of [request] that can be sent again, or null if sending it twice
  /// is not safe (anything but GET and HEAD) or not possible (a stream).
  static http.BaseRequest? _repeatable(http.BaseRequest request) {
    if (request is! http.Request ||
        (request.method != 'GET' && request.method != 'HEAD')) {
      return null;
    }
    final copy = http.Request(request.method, request.url);
    copy.headers.addAll(request.headers);
    copy.followRedirects = request.followRedirects;
    copy.maxRedirects = request.maxRedirects;
    copy.persistentConnection = request.persistentConnection;
    if (request.bodyBytes.isNotEmpty) copy.bodyBytes = request.bodyBytes;
    return copy;
  }

  @override
  void close() {
    _inner.close();
    for (final client in _retired) {
      client.close();
    }
  }
}
