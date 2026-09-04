import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/base64_codec.dart';

void main() {
  group('tryDecodeBase64', () {
    test('decodes standard base64 with padding', () {
      // "hello" -> 5 bytes, not divisible by 3, so it needs padding
      expect(tryDecodeBase64('aGVsbG8='), equals('hello'));
    });

    test('decodes base64 with padding stripped by adding it back', () {
      expect(tryDecodeBase64('aGVsbG8'), equals('hello'));
    });

    test('decodes url-safe base64 containing - and _ characters', () {
      // "a??b" encoded as YT8/Yg==, with '/' swapped for '_'
      expect(tryDecodeBase64('YT8_Yg=='), equals('a??b'));
    });

    test('strips whitespace and newlines before decoding', () {
      expect(tryDecodeBase64('aGVs\nbG8='), equals('hello'));
    });

    test('decodes non-ascii text correctly as utf8', () {
      // "Café 🇳🇱" encoded as base64
      expect(tryDecodeBase64('Q2Fmw6kg8J+Hs/Cfh7E='), equals('Café 🇳🇱'));
    });

    test('returns an empty string for empty input', () {
      expect(tryDecodeBase64(''), equals(''));
    });

    test('returns null for garbage input', () {
      expect(tryDecodeBase64('!!!!'), isNull);
    });

    test('returns null when the bytes are not valid utf8', () {
      expect(tryDecodeBase64('/w=='), isNull);
    });
  });

  group('tryDecodeBase64Bytes', () {
    test('decodes to raw bytes that are not valid utf8', () {
      expect(tryDecodeBase64Bytes('/w=='), equals([0xff]));
    });

    test('returns null for garbage input', () {
      expect(tryDecodeBase64Bytes('!!!!'), isNull);
    });
  });
}
