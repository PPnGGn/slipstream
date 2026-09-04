import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_fetcher.dart';

void main() {
  Future<SubscriptionResponse> fetchWith(Map<String, String> headers) {
    final client = MockClient(
      (_) async => http.Response(
        'vless://uuid@host.example.com:443',
        200,
        headers: headers,
      ),
    );
    return SubscriptionFetcher(client: client).fetch('https://sub.example.com');
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

    test(
      'sends a User-Agent so panels do not serve a fallback format',
      () async {
        String? sentUserAgent;
        final client = MockClient((request) async {
          sentUserAgent = request.headers['User-Agent'];
          return http.Response('vless://uuid@host.example.com:443', 200);
        });

        await SubscriptionFetcher(
          client: client,
        ).fetch('https://sub.example.com');

        expect(sentUserAgent, equals('slipstream'));
      },
    );

    test('throws on a non-200 response', () async {
      final client = MockClient((_) async => http.Response('nope', 403));

      expect(
        () =>
            SubscriptionFetcher(client: client).fetch('https://x.example.com'),
        throwsException,
      );
    });
  });
}
