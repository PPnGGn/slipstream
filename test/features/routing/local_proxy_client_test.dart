import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/routing/data/local_proxy_client.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';

/// Only localProxy() is exercised; anything else would be a test bug.
class _FakeConnection implements VpnConnection {
  _FakeConnection(this._answer);
  final Future<LocalProxyMessage?> Function() _answer;

  @override
  Future<LocalProxyMessage?> localProxy() => _answer();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An HTTP proxy that listens on a Unix socket, like the core's, and records
/// the head of every request it gets. It answers 407 unless the request
/// carries [user]:[pass], then [answer].
class _FakeProxy {
  _FakeProxy._(this._dir, this._server, this.user, this.pass, this.answer);

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

  static Future<_FakeProxy> start({
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
    final proxy = _FakeProxy._(dir, server, user, pass, answer);
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

void main() {
  final proxy = LocalProxyMessage(
    socket: '/tmp/x/h.sock',
    user: 'u1',
    pass: 'p1',
  );

  test('current() returns what the core reports', () async {
    final provider = LocalProxyProvider(
      _FakeConnection(() async => proxy),
      Talker(),
    );
    final got = await provider.current();
    expect(got?.socket, '/tmp/x/h.sock');
    expect(got?.user, 'u1');
    expect(got?.pass, 'p1');
  });

  test('current() is null while no tunnel is up', () async {
    final provider = LocalProxyProvider(
      _FakeConnection(() async => null),
      Talker(),
    );
    expect(await provider.current(), isNull);
  });

  test('a channel error falls back to direct instead of throwing', () async {
    final provider = LocalProxyProvider(
      _FakeConnection(() async => throw Exception('channel down')),
      Talker(),
    );
    expect(await provider.current(), isNull);
  });

  group('buildProxiedClient', () {
    late _FakeProxy fake;

    tearDown(() => fake.close());

    LocalProxyMessage messageFor(_FakeProxy p) =>
        LocalProxyMessage(socket: p.path, user: p.user, pass: p.pass);

    test(
      'sends a plain request over the unix socket, with the password',
      () async {
        fake = await _FakeProxy.start();
        final client = buildProxiedClient(messageFor(fake));
        addTearDown(client.close);

        final response = await client.get(
          Uri.parse('http://example.test/hello'),
        );

        expect(response.statusCode, 200);
        expect(response.body, 'ok');
        expect(fake.heads, hasLength(1));
        expect(fake.heads.single, startsWith('GET http://example.test/hello '));
        expect(fake.authorized, [true]);
      },
    );

    test('reaches HTTPS through CONNECT, with the password', () async {
      // Whatever the proxy says to CONNECT, the TLS handshake that would follow
      // does not happen: the answer is a refusal, and the request has failed.
      fake = await _FakeProxy.start(
        answer: 'HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\n\r\n',
      );
      final client = buildProxiedClient(messageFor(fake));
      addTearDown(client.close);

      await expectLater(
        client.get(Uri.parse('https://example.test/hello')),
        throwsA(anything),
      );

      expect(fake.heads, hasLength(1));
      expect(fake.heads.single, startsWith('CONNECT example.test:443 '));
      expect(fake.authorized, [true]);
    });

    test('a wrong password is refused by the proxy', () async {
      fake = await _FakeProxy.start();
      final wrong = LocalProxyMessage(
        socket: fake.path,
        user: 'u1',
        pass: 'no',
      );
      final client = buildProxiedClient(wrong);
      addTearDown(client.close);

      final response = await client.get(Uri.parse('http://example.test/hello'));

      expect(response.statusCode, 407);
    });

    test('opens no TCP connection to the loopback', () async {
      // The reason for the socket: a listening port of ours is a port any app
      // can find. A TCP listener where the old code used to connect sees
      // nothing now.
      fake = await _FakeProxy.start();
      final decoy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(decoy.close);
      var tcpConnections = 0;
      decoy.listen((s) {
        tcpConnections++;
        s.destroy();
      });
      final client = buildProxiedClient(messageFor(fake));
      addTearDown(client.close);

      await client.get(Uri.parse('http://example.test/hello'));

      expect(tcpConnections, 0);
    });

    test('without a proxy it does not touch the socket', () async {
      fake = await _FakeProxy.start();
      final client = buildProxiedClient(null);
      addTearDown(client.close);

      expect(client, isNotNull);
      expect(fake.heads, isEmpty);
    });
  });

  // The core picks a new password in every session. A client built before it
  // restarted (a long download is one) still carries the old one, and the proxy
  // answers 407 to it: the request must go again with what the core reports
  // now, instead of failing the whole download.
  group('after the core restarted', () {
    late _FakeProxy fake;

    tearDown(() => fake.close());

    LocalProxyMessage msg(String pass) =>
        LocalProxyMessage(socket: fake.path, user: fake.user, pass: pass);

    final hello = Uri.parse('http://example.test/hello');

    test('a plain request is repeated once with the new password', () async {
      fake = await _FakeProxy.start();
      var asked = 0;
      final client = buildProxiedClient(
        msg('p1'),
        refresh: () async {
          asked++;
          return msg('p2');
        },
      );
      addTearDown(client.close);
      fake.pass = 'p2';

      final response = await client.get(hello);

      expect(response.statusCode, 200);
      expect(response.body, 'ok');
      expect(fake.authorized, [false, true]);
      expect(asked, 1);
    });

    test('so is one to an HTTPS host (the CONNECT)', () async {
      fake = await _FakeProxy.start(
        answer: 'HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\n\r\n',
      );
      final client = buildProxiedClient(
        msg('p1'),
        refresh: () async => msg('p2'),
      );
      addTearDown(client.close);
      fake.pass = 'p2';

      await expectLater(
        client.get(Uri.parse('https://example.test/hello')),
        throwsA(anything), // the 502 of the fake after the password was right
      );

      expect(fake.heads, hasLength(2));
      expect(fake.heads, everyElement(startsWith('CONNECT example.test:443 ')));
      expect(fake.authorized, [false, true]);
    });

    test('the new password is kept for the next requests', () async {
      fake = await _FakeProxy.start();
      var asked = 0;
      final client = buildProxiedClient(
        msg('p1'),
        refresh: () async {
          asked++;
          return msg('p2');
        },
      );
      addTearDown(client.close);
      fake.pass = 'p2';

      await client.get(hello);
      final second = await client.get(hello);

      expect(second.statusCode, 200);
      expect(fake.authorized, [false, true, true]);
      expect(asked, 1);
    });

    test('headers go again with the repeated request', () async {
      fake = await _FakeProxy.start();
      final client = buildProxiedClient(
        msg('p1'),
        refresh: () async => msg('p2'),
      );
      addTearDown(client.close);
      fake.pass = 'p2';

      await client.get(hello, headers: {'X-Test': 'yes'});

      expect(fake.heads, hasLength(2));
      for (final head in fake.heads) {
        expect(head.toLowerCase(), contains('x-test: yes'));
      }
    });

    test('requests that fail together all recover', () async {
      fake = await _FakeProxy.start();
      final client = buildProxiedClient(
        msg('p1'),
        refresh: () async => msg('p2'),
      );
      addTearDown(client.close);
      fake.pass = 'p2';

      final responses = await Future.wait([
        for (var i = 0; i < 4; i++) client.get(hello),
      ]);

      expect(responses.map((r) => r.statusCode), everyElement(200));
      expect(fake.authorized.where((ok) => ok), hasLength(4));
    });

    test('nothing is asked while the password is right', () async {
      fake = await _FakeProxy.start();
      var asked = 0;
      final client = buildProxiedClient(
        msg('p1'),
        refresh: () async {
          asked++;
          return msg('p2');
        },
      );
      addTearDown(client.close);

      final response = await client.get(hello);

      expect(response.statusCode, 200);
      expect(asked, 0);
    });

    test(
      'it does not repeat when the core reports the same password',
      () async {
        fake = await _FakeProxy.start();
        final client = buildProxiedClient(
          msg('p1'),
          refresh: () async => msg('p1'),
        );
        addTearDown(client.close);
        fake.pass = 'p2'; // wrong for a reason a retry cannot cure

        final response = await client.get(hello);

        expect(response.statusCode, 407);
        expect(fake.authorized, [false]);
      },
    );

    test('nor when no tunnel is up', () async {
      fake = await _FakeProxy.start();
      final client = buildProxiedClient(msg('p1'), refresh: () async => null);
      addTearDown(client.close);
      fake.pass = 'p2';

      final response = await client.get(hello);

      expect(response.statusCode, 407);
      expect(fake.authorized, [false]);
    });

    test('it repeats once only', () async {
      fake = await _FakeProxy.start();
      var asked = 0;
      final client = buildProxiedClient(
        msg('p1'),
        refresh: () async {
          asked++;
          return msg('p3'); // not the password of the proxy either
        },
      );
      addTearDown(client.close);
      fake.pass = 'p2';

      final response = await client.get(hello);

      expect(response.statusCode, 407);
      expect(fake.authorized, [false, false]);
      expect(asked, 1);
    });

    test('a request with a body is not repeated', () async {
      fake = await _FakeProxy.start();
      var asked = 0;
      final client = buildProxiedClient(
        msg('p1'),
        refresh: () async {
          asked++;
          return msg('p2');
        },
      );
      addTearDown(client.close);
      fake.pass = 'p2';

      final response = await client.post(hello, body: 'x');

      expect(response.statusCode, 407);
      expect(fake.authorized, [false]);
      expect(asked, 0);
    });

    test('the factory for the geo download follows the provider', () async {
      fake = await _FakeProxy.start();
      var pass = 'p1';
      final provider = LocalProxyProvider(
        _FakeConnection(() async => msg(pass)),
        Talker(),
      );
      final client = refreshingProxyClientFactory(provider)(
        await provider.current(),
      );
      addTearDown(client.close);
      pass = 'p2'; // the core restarts ...
      fake.pass = 'p2'; // ... and reports the new password

      final response = await client.get(hello);

      expect(response.statusCode, 200);
      expect(fake.authorized, [false, true]);
    });

    test('the factory gives a plain client when no tunnel is up', () async {
      fake = await _FakeProxy.start();
      final provider = LocalProxyProvider(
        _FakeConnection(() async => null),
        Talker(),
      );
      final client = refreshingProxyClientFactory(provider)(null);
      addTearDown(client.close);

      expect(client, isNotNull);
      expect(fake.heads, isEmpty);
    });
  });
}
