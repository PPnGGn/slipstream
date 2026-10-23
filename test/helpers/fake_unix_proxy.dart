import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:slipstream/features/vpn/data/vpn_api.g.dart';

/// Only localProxy() is exercised; anything else would be a test bug.
class FakeVpnConnection implements VpnConnection {
  FakeVpnConnection(this._answer);
  final Future<LocalProxyMessage?> Function() _answer;

  @override
  Future<LocalProxyMessage?> localProxy() => _answer();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An HTTP proxy that listens on a Unix socket, like the core's, and records
/// the head of every request it gets. It answers 407 unless the request
/// carries [user]:[pass], then [answer].
class FakeUnixProxy {
  FakeUnixProxy._(this._dir, this._server, this.user, this.pass, this.answer);

  final Directory _dir;
  final ServerSocket _server;
  final String user;

  /// Changed by a test to stand for a restart of the core: the same socket, a
  /// password of a new session.
  String pass;
  final String answer;
  final heads = <String>[];

  /// For each request in [heads]: did it carry the right credentials.
  final authorized = <bool>[];

  String get path => _server.address.address;

  /// What the core's message says about this proxy with [password].
  LocalProxyMessage message([String? password]) =>
      LocalProxyMessage(socket: path, user: user, pass: password ?? pass);

  static Future<FakeUnixProxy> start({
    String user = 'u1',
    String pass = 'p1',
    // "Connection: close", as the fake closes the socket after each answer: the
    // client must not keep the connection for the next request.
    String answer =
        'HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length: 2\r\n\r\nok',
  }) async {
    // /tmp, not the system temp dir: a socket path is limited to about 100
    // bytes, and that of macOS is longer.
    final dir = await Directory('/tmp').createTemp('slip');
    final server = await ServerSocket.bind(
      InternetAddress('${dir.path}/h.sock', type: InternetAddressType.unix),
      0,
    );
    final proxy = FakeUnixProxy._(dir, server, user, pass, answer);
    server.listen(proxy._serve);
    return proxy;
  }

  void _serve(Socket socket) {
    final buffer = StringBuffer();
    late StreamSubscription<List<int>> sub;
    sub = socket.listen((data) {
      buffer.write(latin1.decode(data));
      final text = buffer.toString();
      if (!text.contains('\r\n\r\n')) return;
      sub.cancel();
      final head = text.substring(0, text.indexOf('\r\n\r\n'));
      heads.add(head);
      // Header names are case-insensitive, and Dart writes them in lower case;
      // the value is compared as it is.
      final wanted = 'Basic ${base64.encode(utf8.encode('$user:$pass'))}';
      final ok = head.split('\r\n').any((line) {
        final colon = line.indexOf(':');
        return colon > 0 &&
            line.substring(0, colon).toLowerCase() == 'proxy-authorization' &&
            line.substring(colon + 1).trim() == wanted;
      });
      authorized.add(ok);
      socket.write(
        ok
            ? answer
            : 'HTTP/1.1 407 Proxy Authentication Required\r\n'
                  'Proxy-Authenticate: Basic realm="x"\r\n'
                  'Connection: close\r\n'
                  'Content-Length: 0\r\n\r\n',
      );
      socket.flush().whenComplete(socket.close);
    });
  }

  Future<void> close() async {
    await _server.close();
    await _dir.delete(recursive: true);
  }
}
