import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:slipstream/features/client_identity/data/hwid.dart';
import 'package:slipstream/features/routing/data/local_proxy_client.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_fetcher.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';

import '../../../client_identity/fakes.dart';

/// The tunnel's local proxy: [message] null means no tunnel is up.
class _FakeProxy implements LocalProxyProvider {
  _FakeProxy(this.message);

  final LocalProxyMessage? message;
  int calls = 0;

  @override
  Future<LocalProxyMessage?> current() async {
    calls++;
    return message;
  }
}

final _tunnel = LocalProxyMessage(socket: '/tmp/h.sock', user: 'u', pass: 'p');

void main() {
  Future<SubscriptionFetcher> fetcherOn(
    http.Client client, {
    FakeDeviceInfoApi? api,
  }) async => SubscriptionFetcher(
    await identityRepositoryWith(api ?? FakeDeviceInfoApi(deviceId: 'abc')),
    _FakeProxy(null),
    clientFactory: (_) => client,
  );

  Future<SubscriptionResponse> fetchWith(Map<String, String> headers) async {
    final client = MockClient(
      (_) async => http.Response(
        'vless://uuid@host.example.com:443',
        200,
        headers: headers,
      ),
    );
    final fetcher = await fetcherOn(client);
    return fetcher.fetch('https://sub.example.com');
  }

  group('SubscriptionFetcher headers', () {
    test('keeps a plain text profile-title as is', () async {
      final response = await fetchWith({'profile-title': 'My VPN'});

      expect(response.profileTitle, equals('My VPN'));
    });

    test('keeps a plain title that happens to be valid base64', () async {
      // "Fast" decodes as base64 but is meant to be read literally
      final response = await fetchWith({'profile-title': 'Fast'});

      expect(response.profileTitle, equals('Fast'));
    });

    test('decodes a title marked with the base64: prefix', () async {
      final encoded = base64.encode(utf8.encode('Моя подписка'));
      final response = await fetchWith({'profile-title': 'base64:$encoded'});

      expect(response.profileTitle, equals('Моя подписка'));
    });

    test(
      'falls back to the raw header when base64: payload is broken',
      () async {
        final response = await fetchWith({'profile-title': 'base64:!!!!'});

        expect(response.profileTitle, equals('base64:!!!!'));
      },
    );

    test('parses traffic and expiry from subscription-userinfo', () async {
      final response = await fetchWith({
        'subscription-userinfo':
            'upload=100; download=900; total=5000; expire=1800000000',
      });

      expect(response.usedBytes, equals(1000));
      expect(response.dataLimitBytes, equals(5000));
      expect(
        response.expiresAt,
        equals(DateTime.fromMillisecondsSinceEpoch(1800000000 * 1000)),
      );
    });

    test('leaves usage fields null when the header is absent', () async {
      final response = await fetchWith({});

      expect(response.usedBytes, isNull);
      expect(response.dataLimitBytes, isNull);
      expect(response.expiresAt, isNull);
      expect(response.profileTitle, isNull);
    });

    test('masks the User-Agent as a whitelisted client so panels do not serve '
        'a decoy/fallback format', () async {
      String? sentUserAgent;
      final client = MockClient((request) async {
        sentUserAgent = request.headers['User-Agent'];
        return http.Response('vless://uuid@host.example.com:443', 200);
      });

      final fetcher = await fetcherOn(client);
      await fetcher.fetch('https://sub.example.com');

      // The panel matcher is prefix-anchored on 'Happ/'; the version is free.
      expect(sentUserAgent, startsWith('Happ/'));
    });

    test('throws on a non-200 response', () async {
      final client = MockClient((_) async => http.Response('nope', 403));
      final fetcher = await fetcherOn(client);

      expect(() => fetcher.fetch('https://x.example.com'), throwsException);
    });
  });

  group('SubscriptionFetcher panel device-limit replies', () {
    Future<SubscriptionResponse> fetchReplying(
      int status,
      Map<String, String> headers,
    ) async {
      final client = MockClient(
        (_) async => http.Response('', status, headers: headers),
      );
      final fetcher = await fetcherOn(client);
      return fetcher.fetch('https://sub.example.com');
    }

    test('maps x-hwid-max-devices-reached to a device limit error', () {
      expect(
        fetchReplying(403, {'x-hwid-max-devices-reached': 'true'}),
        throwsA(isA<DeviceLimitReachedException>()),
      );
    });

    test('checks the limit header on a 200 response too', () {
      expect(
        fetchReplying(200, {'x-hwid-max-devices-reached': 'true'}),
        throwsA(isA<DeviceLimitReachedException>()),
      );
    });

    test('maps 404 with x-hwid-not-supported to an HWID required error', () {
      expect(
        fetchReplying(404, {'x-hwid-not-supported': 'true'}),
        throwsA(isA<HwidRequiredException>()),
      );
    });

    test('reads the header value case-insensitively', () {
      expect(
        fetchReplying(404, {'x-hwid-not-supported': 'True'}),
        throwsA(isA<HwidRequiredException>()),
      );
    });

    test('ignores x-hwid-not-supported on a non-404 status', () {
      expect(
        fetchReplying(500, {'x-hwid-not-supported': 'true'}),
        throwsA(
          isA<Exception>().having(
            (e) => e,
            'type',
            isNot(isA<HwidRequiredException>()),
          ),
        ),
      );
    });

    test('a plain 404 stays a generic HTTP error', () {
      expect(
        fetchReplying(404, {}),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('HTTP error: 404'),
          ),
        ),
      );
    });

    test('the messages tell the user what to do', () {
      expect(
        DeviceLimitReachedException().toString(),
        allOf(contains('device limit'), contains('remove')),
      );
      expect(HwidRequiredException().toString(), contains('HWID'));
    });
  });

  group('SubscriptionFetcher client identity', () {
    Future<Map<String, String>> sentHeaders(FakeDeviceInfoApi api) async {
      late Map<String, String> sent;
      final client = MockClient((request) async {
        sent = request.headers;
        return http.Response('vless://uuid@host.example.com:443', 200);
      });
      final fetcher = await fetcherOn(client, api: api);

      await fetcher.fetch('https://sub.example.com');
      return sent;
    }

    test('sends all five identity headers', () async {
      final headers = await sentHeaders(
        FakeDeviceInfoApi(
          deviceId: 'abc',
          os: 'Android',
          osVersion: '14',
          model: 'Pixel 8',
        ),
      );

      expect(headers['User-Agent'], startsWith('Happ/'));
      expect(headers['x-hwid'], equals(hwidFromDeviceId('abc')));
      expect(headers['x-device-os'], equals('Android'));
      expect(headers['x-ver-os'], equals('14'));
      expect(headers['x-device-model'], equals('Pixel 8'));
    });

    test('sends the same HWID on every request', () async {
      final seen = <String?>[];
      final client = MockClient((request) async {
        seen.add(request.headers['x-hwid']);
        return http.Response('vless://uuid@host.example.com:443', 200);
      });
      final fetcher = await fetcherOn(client);

      await fetcher.fetch('https://sub.example.com');
      await fetcher.fetch('https://sub.example.com');

      expect(seen, hasLength(2));
      expect(seen[0], equals(seen[1]));
    });

    test(
      'still sends User-Agent and HWID when the device info fails',
      () async {
        final headers = await sentHeaders(
          FakeDeviceInfoApi(error: StateError('no bridge')),
        );

        expect(headers['User-Agent'], startsWith('Happ/'));
        expect(isValidHwid(headers['x-hwid']!), isTrue);
        expect(headers.containsKey('x-device-os'), isFalse);
        expect(headers.containsKey('x-ver-os'), isFalse);
        expect(headers.containsKey('x-device-model'), isFalse);
      },
    );
  });

  group('SubscriptionFetcher tunnel fallback', () {
    const body = 'vless://uuid@host.example.com:443';

    /// Answers direct requests with [direct] and proxied ones with a 200,
    /// recording which proxy each client was built for.
    Future<(SubscriptionFetcher, List<LocalProxyMessage?>)> fetcherWith({
      required Future<http.Response> Function() direct,
      LocalProxyMessage? tunnel,
      _FakeProxy? proxy,
    }) async {
      final built = <LocalProxyMessage?>[];
      final fetcher = SubscriptionFetcher(
        await identityRepositoryWith(FakeDeviceInfoApi(deviceId: 'abc')),
        proxy ?? _FakeProxy(tunnel),
        clientFactory: (message) {
          built.add(message);
          return MockClient(
            (_) => message == null
                ? direct()
                : Future.value(http.Response(body, 200)),
          );
        },
      );
      return (fetcher, built);
    }

    test('a working direct request never asks for the tunnel', () async {
      final proxy = _FakeProxy(_tunnel);
      final (fetcher, built) = await fetcherWith(
        direct: () async => http.Response(body, 200),
        proxy: proxy,
      );

      final response = await fetcher.fetch('https://sub.example.com');

      expect(response.body, body);
      expect(built, [null]);
      expect(proxy.calls, 0);
    });

    test('a blocked direct request is retried through the tunnel', () async {
      final (fetcher, built) = await fetcherWith(
        direct: () => throw const SocketException('Connection reset by peer'),
        tunnel: _tunnel,
      );

      final response = await fetcher.fetch('https://sub.example.com');

      expect(response.body, body);
      expect(built, [null, _tunnel]);
    });

    test('a TLS failure (DPI reset) is retried through the tunnel', () async {
      final (fetcher, built) = await fetcherWith(
        direct: () => throw const HandshakeException('Connection terminated'),
        tunnel: _tunnel,
      );

      await fetcher.fetch('https://sub.example.com');

      expect(built, [null, _tunnel]);
    });

    test('an http client error is retried through the tunnel', () async {
      final (fetcher, built) = await fetcherWith(
        direct: () => throw http.ClientException('Connection closed'),
        tunnel: _tunnel,
      );

      await fetcher.fetch('https://sub.example.com');

      expect(built, [null, _tunnel]);
    });

    test('without a tunnel the network error surfaces', () async {
      final (fetcher, built) = await fetcherWith(
        direct: () => throw const SocketException('Network is unreachable'),
      );

      await expectLater(
        fetcher.fetch('https://sub.example.com'),
        throwsA(isA<SocketException>()),
      );
      expect(built, [null]);
    });

    test('an HTTP error status is the panel answering: no retry', () async {
      final proxy = _FakeProxy(_tunnel);
      final (fetcher, built) = await fetcherWith(
        direct: () async => http.Response('nope', 500),
        proxy: proxy,
      );

      await expectLater(
        fetcher.fetch('https://sub.example.com'),
        throwsException,
      );
      expect(built, [null]);
      expect(proxy.calls, 0);
    });

    test('a device limit reply is not retried through the tunnel', () async {
      final (fetcher, built) = await fetcherWith(
        direct: () async => http.Response(
          '',
          403,
          headers: {'x-hwid-max-devices-reached': 'true'},
        ),
        tunnel: _tunnel,
      );

      await expectLater(
        fetcher.fetch('https://sub.example.com'),
        throwsA(isA<DeviceLimitReachedException>()),
      );
      expect(built, [null]);
    });
  });
}
