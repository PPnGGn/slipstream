import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/routing/data/local_proxy_client.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';

import '../../helpers/fake_unix_proxy.dart';

void main() {
  final proxy = LocalProxyMessage(
    socket: '/tmp/x/h.sock',
    user: 'u1',
    pass: 'p1',
  );

  test('current() returns what the core reports', () async {
    final provider = LocalProxyProvider(
      FakeVpnConnection(() async => proxy),
      Talker(),
    );
    final got = await provider.current();
    expect(got?.socket, '/tmp/x/h.sock');
    expect(got?.user, 'u1');
    expect(got?.pass, 'p1');
  });

  test('current() is null while no tunnel is up', () async {
    final provider = LocalProxyProvider(
      FakeVpnConnection(() async => null),
      Talker(),
    );
    expect(await provider.current(), isNull);
  });

  test('a channel error falls back to direct instead of throwing', () async {
    final provider = LocalProxyProvider(
      FakeVpnConnection(() async => throw Exception('channel down')),
      Talker(),
    );
    expect(await provider.current(), isNull);
  });

  group('buildProxiedClient', () {
    late FakeUnixProxy fake;

    tearDown(() => fake.close());

    LocalProxyMessage messageFor(FakeUnixProxy p) =>
        LocalProxyMessage(socket: p.path, user: p.user, pass: p.pass);

    test(
      'sends a plain request over the unix socket, with the password',
      () async {
        fake = await FakeUnixProxy.start();
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
      fake = await FakeUnixProxy.start(
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
      fake = await FakeUnixProxy.start();
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
      fake = await FakeUnixProxy.start();
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
      fake = await FakeUnixProxy.start();
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
    late FakeUnixProxy fake;

    tearDown(() => fake.close());

    LocalProxyMessage msg(String pass) =>
        LocalProxyMessage(socket: fake.path, user: fake.user, pass: pass);

    final hello = Uri.parse('http://example.test/hello');

    test('a plain request is repeated once with the new password', () async {
      fake = await FakeUnixProxy.start();
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
      fake = await FakeUnixProxy.start(
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
      fake = await FakeUnixProxy.start();
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
      fake = await FakeUnixProxy.start();
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
      fake = await FakeUnixProxy.start();
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
      fake = await FakeUnixProxy.start();
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
        fake = await FakeUnixProxy.start();
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
      fake = await FakeUnixProxy.start();
      final client = buildProxiedClient(msg('p1'), refresh: () async => null);
      addTearDown(client.close);
      fake.pass = 'p2';

      final response = await client.get(hello);

      expect(response.statusCode, 407);
      expect(fake.authorized, [false]);
    });

    test('it repeats once only', () async {
      fake = await FakeUnixProxy.start();
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
      fake = await FakeUnixProxy.start();
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
      fake = await FakeUnixProxy.start();
      var pass = 'p1';
      final provider = LocalProxyProvider(
        FakeVpnConnection(() async => msg(pass)),
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
      fake = await FakeUnixProxy.start();
      final provider = LocalProxyProvider(
        FakeVpnConnection(() async => null),
        Talker(),
      );
      final client = refreshingProxyClientFactory(provider)(null);
      addTearDown(client.close);

      expect(client, isNotNull);
      expect(fake.heads, isEmpty);
    });
  });
}
