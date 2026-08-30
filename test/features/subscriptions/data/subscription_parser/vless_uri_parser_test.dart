import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/vless_uri_parser.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/xray_config_builder.dart';

void main() {
  final parser = VlessUriParser(Talker(), XrayConfigBuilder());

  group('VlessUriParser.isVless', () {
    test('returns true for a plain vless:// link', () {
      final result = parser.isVless('vless://uuid@host:443');

      expect(result, isTrue);
    });

    test('returns true regardless of scheme casing', () {
      final result = parser.isVless('VLESS://uuiD@host:443');

      expect(result, isTrue);
    });

    test('returns true when the link has surrounding whitespace', () {
      final result = parser.isVless('   vless://uuid@host:443   ');

      expect(result, isTrue);
    });

    test('returns false for a non-vless scheme', () {
      final result = parser.isVless('https://example.com/subscription');

      expect(result, isFalse);
    });

    test('returns false for an empty string', () {
      final result = parser.isVless('');

      expect(result, isFalse);
    });
  });

  group('VlessUriParser.parseLines', () {
    test('parses a single valid link and fills every field', () {
      final link =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443'
          '?sni=example.com&pbk=publicKey123&sid=abcd&fp=firefox&flow=xtls-rprx-vision'
          '#%F0%9F%87%B3%F0%9F%87%B1%20Netherlands%20%231';

      final servers = parser.parseLines(link, 'my-subscription');

      expect(servers, hasLength(1));
      final server = servers.first;
      expect(
        server.id,
        equals('example.com:443:11111111-1111-1111-1111-111111111111:#0'),
      );
      expect(server.subscriptionId, equals('my-subscription'));
      expect(server.title, equals('🇳🇱 Netherlands #1'));
      expect(server.countryCode, equals('NL'));
      expect(server.configJson, contains('"publicKey":"publicKey123"'));
    });

    test('falls back to "address:port" as title when there is no fragment', () {
      final link =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443';

      final servers = parser.parseLines(link, 'my-subscription');

      expect(servers.single.title, equals('example.com:443'));
    });

    test('defaults fingerprint to "chrome" when fp is missing', () {
      final link =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443';

      final servers = parser.parseLines(link, 'my-subscription');

      expect(servers.single.configJson, contains('"fingerprint":"chrome"'));
    });

    test('skips a broken line but keeps the valid ones around it', () {
      const validLine =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443';
      const brokenLine = 'vless://no-host-or-port';
      final text = '$validLine\n$brokenLine\n$validLine';

      final servers = parser.parseLines(text, 'my-subscription');

      expect(servers, hasLength(2));
    });

    test('skips a link with no uuid in the user info', () {
      final link = 'vless://@example.com:443';

      final servers = parser.parseLines(link, 'my-subscription');

      expect(servers, isEmpty);
    });

    test('skips a link with an out-of-range port', () {
      final tooLow =
          'vless://11111111-1111-1111-1111-111111111111@example.com:0';
      final tooHigh =
          'vless://11111111-1111-1111-1111-111111111111@example.com:70000';

      final servers = parser.parseLines('$tooLow\n$tooHigh', 'my-subscription');

      expect(servers, isEmpty);
    });

    test('ignores non-vless lines mixed into the text', () {
      const validLine =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443';
      final text = 'https://example.com/other\n$validLine\nnot a link at all';

      final servers = parser.parseLines(text, 'my-subscription');

      expect(servers, hasLength(1));
    });

    test('ignores blank lines and CRLF line endings', () {
      const validLine =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443';
      final text = '\r\n$validLine\r\n\r\n$validLine\r\n';

      final servers = parser.parseLines(text, 'my-subscription');

      expect(servers, hasLength(2));
    });
  });
}
