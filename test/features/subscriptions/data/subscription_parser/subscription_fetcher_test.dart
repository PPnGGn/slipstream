import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:slipstream/features/client_identity/data/hwid.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_fetcher.dart';

import '../../../client_identity/fakes.dart';

void main() {
  Future<SubscriptionFetcher> fetcherOn(
    http.Client client, {
    FakeDeviceInfoApi? api,
  }) async => SubscriptionFetcher(
    await identityRepositoryWith(api ?? FakeDeviceInfoApi(deviceId: 'abc')),
    client: client,
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
}
