import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/vless_uri_parser.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/xray_config_builder.dart';

void main() {
  final parser = VlessUriParser(Talker(), XrayConfigBuilder());

  group('VlessUriParser.matches', () {
    test('returns true for a plain vless:// link', () {
      final result = parser.matches('vless://uuid@host:443');

      expect(result, isTrue);
    });

    test('returns true regardless of scheme casing', () {
      final result = parser.matches('VLESS://uuiD@host:443');

      expect(result, isTrue);
    });

    test('returns true when the link has surrounding whitespace', () {
      final result = parser.matches('   vless://uuid@host:443   ');

      expect(result, isTrue);
    });

    test('returns false for a non-vless scheme', () {
      final result = parser.matches('https://example.com/subscription');

      expect(result, isFalse);
    });

    test('returns false for an empty string', () {
      final result = parser.matches('');

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
          'vless://11111111-1111-1111-1111-111111111111@example.com:443'
          '?security=reality&pbk=publicKey123&sni=example.com';

      final servers = parser.parseLines(link, 'my-subscription');

      expect(servers.single.configJson, contains('"fingerprint":"chrome"'));
    });

    test('treats a link without any params as plain tcp without security', () {
      final link =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443';

      final servers = parser.parseLines(link, 'my-subscription');

      final stream = _streamSettingsOf(servers.single.configJson);
      expect(stream['network'], equals('tcp'));
      expect(stream['security'], equals('none'));
      expect(stream.containsKey('tlsSettings'), isFalse);
      expect(stream.containsKey('realitySettings'), isFalse);
    });

    test('guesses reality security from the presence of pbk', () {
      final link =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443'
          '?pbk=publicKey123&sni=example.com';

      final servers = parser.parseLines(link, 'my-subscription');

      final stream = _streamSettingsOf(servers.single.configJson);
      expect(stream['security'], equals('reality'));
    });

    test('builds a ws+tls config with path and host header', () {
      final link =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443'
          '?type=ws&security=tls&sni=cdn.example.com'
          '&path=%2Fws-path&host=cdn.example.com';

      final servers = parser.parseLines(link, 'my-subscription');

      final stream = _streamSettingsOf(servers.single.configJson);
      expect(stream['network'], equals('ws'));
      expect(stream['security'], equals('tls'));
      expect(stream['tlsSettings']['serverName'], equals('cdn.example.com'));
      expect(stream['wsSettings']['path'], equals('/ws-path'));
      expect(
        stream['wsSettings']['headers']['Host'],
        equals('cdn.example.com'),
      );
    });

    test('builds a grpc+reality config with serviceName', () {
      final link =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443'
          '?type=grpc&security=reality&pbk=publicKey123&sni=example.com'
          '&serviceName=my-service';

      final servers = parser.parseLines(link, 'my-subscription');

      final stream = _streamSettingsOf(servers.single.configJson);
      expect(stream['network'], equals('grpc'));
      expect(stream['grpcSettings']['serviceName'], equals('my-service'));
      expect(stream['realitySettings']['publicKey'], equals('publicKey123'));
    });

    test('builds an xhttp config preserving path and mode', () {
      final link =
          'vless://1111-1111-1111-1111-111111111111@example.com:443'
          '?type=xhttp&security=reality&pbk=publicKey123&sni=example.com'
          '&path=%2Fmedia%2Ffragments%2F&mode=auto';

      final servers = parser.parseLines(link, 'my-subscription');

      final stream = _streamSettingsOf(servers.single.configJson);
      expect(stream['network'], equals('xhttp'));
      expect(stream['xhttpSettings']['path'], equals('/media/fragments/'));
      expect(stream['xhttpSettings']['mode'], equals('auto'));
    });

    test('does not set flow on non-tcp networks', () {
      final link =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443'
          '?type=ws&security=tls&flow=xtls-rprx-vision';

      final servers = parser.parseLines(link, 'my-subscription');

      expect(servers.single.configJson, isNot(contains('"flow"')));
    });

    test('does not invent a flow when the link has none', () {
      final link =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443'
          '?type=tcp&security=reality&pbk=publicKey123&sni=example.com';

      final servers = parser.parseLines(link, 'my-subscription');

      expect(servers.single.configJson, isNot(contains('"flow"')));
    });

    test('keeps a plus sign in the path instead of decoding it to a space', () {
      final link =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443'
          '?type=ws&security=tls&sni=example.com&path=/a+b';

      final servers = parser.parseLines(link, 'my-subscription');

      final stream = _streamSettingsOf(servers.single.configJson);
      expect(stream['wsSettings']['path'], equals('/a+b'));
    });

    test('trims whitespace between alpn values', () {
      final link =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443'
          '?type=tcp&security=tls&sni=example.com&alpn=h2,%20http/1.1';

      final servers = parser.parseLines(link, 'my-subscription');

      final stream = _streamSettingsOf(servers.single.configJson);
      expect(stream['tlsSettings']['alpn'], equals(['h2', 'http/1.1']));
    });

    test('turns on grpc multiMode for mode=multi', () {
      final link =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443'
          '?type=grpc&security=tls&sni=example.com&serviceName=svc&mode=multi';

      final servers = parser.parseLines(link, 'my-subscription');

      final stream = _streamSettingsOf(servers.single.configJson);
      expect(stream['grpcSettings']['multiMode'], isTrue);
      expect(stream['grpcSettings']['serviceName'], equals('svc'));
    });

    test('leaves grpc multiMode off for gun mode', () {
      final link =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443'
          '?type=grpc&security=tls&sni=example.com&mode=gun';

      final servers = parser.parseLines(link, 'my-subscription');

      final stream = _streamSettingsOf(servers.single.configJson);
      expect(stream['grpcSettings']['multiMode'], isFalse);
    });

    test('passes the encryption parameter through', () {
      final link =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443'
          '?type=tcp&encryption=mlkem768x25519plus';

      final servers = parser.parseLines(link, 'my-subscription');

      expect(
        servers.single.configJson,
        contains('"encryption":"mlkem768x25519plus"'),
      );
    });

    test('defaults encryption to none when the link has none', () {
      final link =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443';

      final servers = parser.parseLines(link, 'my-subscription');

      expect(servers.single.configJson, contains('"encryption":"none"'));
    });

    test('builds the http header request for headerType=http on tcp', () {
      final link =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443'
          '?type=tcp&headerType=http&host=www.bing.com&path=/news';

      final servers = parser.parseLines(link, 'my-subscription');

      final header = _streamSettingsOf(
        servers.single.configJson,
      )['tcpSettings']['header'];
      expect(header['type'], equals('http'));
      expect(header['request']['path'], equals(['/news']));
      expect(header['request']['headers']['Host'], equals(['www.bing.com']));
    });

    test('skips a reality link with no public key', () {
      final link =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443'
          '?type=tcp&security=reality&sni=example.com';

      final servers = parser.parseLines(link, 'my-subscription');

      expect(servers, isEmpty);
    });

    test('skips a link with an unknown network type', () {
      final link =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443'
          '?type=quic';

      final servers = parser.parseLines(link, 'my-subscription');

      expect(servers, isEmpty);
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

Map<String, dynamic> _streamSettingsOf(String configJson) {
  final json = jsonDecode(configJson) as Map<String, dynamic>;
  final outbounds = (json['outbounds'] as List).cast<Map<String, dynamic>>();
  final proxy = outbounds.firstWhere((o) => o['tag'] == 'proxy');
  return (proxy['streamSettings'] as Map).cast<String, dynamic>();
}
