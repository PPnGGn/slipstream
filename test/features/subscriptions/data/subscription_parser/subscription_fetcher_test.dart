import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_fetcher.dart';

void main() {
  final fetcher = SubscriptionFetcher();

  group('SubscriptionFetcher.decodeBase64', () {
    test('decodes standard base64 with padding', () {
      // "hello" -> 5 bytes, not divisible by 3, so it needs padding
      final decoded = fetcher.decodeBase64('aGVsbG8=');

      expect(decoded, equals('hello'));
    });

    test('decodes base64 with padding stripped by adding it back', () {
      final decoded = fetcher.decodeBase64('aGVsbG8');

      expect(decoded, equals('hello'));
    });

    test('decodes url-safe base64 containing - and _ characters', () {
      // "a??b" encoded as YT8/Yg==, with '/' swapped for '_'
      final decoded = fetcher.decodeBase64('YT8_Yg==');

      expect(decoded, equals('a??b'));
    });

    test('strips whitespace and newlines before decoding', () {
      final decoded = fetcher.decodeBase64('aGVs\nbG8=');

      expect(decoded, equals('hello'));
    });

    test('decodes non-ascii text correctly as utf8', () {
      // "Café 🇳🇱" encoded as base64
      final decoded = fetcher.decodeBase64('Q2Fmw6kg8J+Hs/Cfh7E=');

      expect(decoded, equals('Café 🇳🇱'));
    });

    test('returns an empty string for empty input', () {
      final decoded = fetcher.decodeBase64('');

      expect(decoded, equals(''));
    });

    test('throws FormatException for garbage input', () {
      expect(
        () => fetcher.decodeBase64('!!!!'),
        throwsFormatException,
      );
    });
  });
}
