import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/hysteria2_uri_parser.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/xray_config_builder.dart';

void main() {
  final parser = Hysteria2UriParser(Talker(), XrayConfigBuilder());

  Map<String, dynamic> proxyOf(String configJson) {
    final json = jsonDecode(configJson) as Map<String, dynamic>;
    return (json['outbounds'] as List).cast<Map<String, dynamic>>().firstWhere(
      (o) => o['tag'] == 'proxy',
    );
  }

  group('Hysteria2UriParser.matches', () {
    test('returns true for a hysteria2:// link', () {
      expect(parser.matches('hysteria2://auth@host:443'), isTrue);
    });

    test('returns true for a hy2:// link', () {
      expect(parser.matches('hy2://auth@host:443'), isTrue);
    });

    test('returns true regardless of scheme casing', () {
      expect(parser.matches('HYSTERIA2://auth@host:443'), isTrue);
    });

    test('returns false for another scheme', () {
      expect(parser.matches('vless://uuid@host:443'), isFalse);
    });
  });

  group('Hysteria2UriParser.parseLines', () {
    test('parses a full link with salamander obfs and fills every field', () {
      final link =
          'hysteria2://auth-password@example.com:443'
          '?obfs=salamander&obfs-password=obfs-secret&sni=example.com'
          '#%F0%9F%87%B3%F0%9F%87%B1%20Netherlands%20%231';

      final servers = parser.parseLines(link, 'my-subscription');

      expect(servers, hasLength(1));
      final server = servers.single;
      expect(server.id, equals('example.com:443:auth-password:#0'));
      expect(server.subscriptionId, equals('my-subscription'));
      expect(server.title, equals('🇳🇱 Netherlands #1'));
      expect(server.countryCode, equals('NL'));

      final proxy = proxyOf(server.configJson);
      expect(proxy['protocol'], equals('hysteria'));
      expect(proxy['settings']['version'], equals(2));
      expect(proxy['settings']['address'], equals('example.com'));
      expect(proxy['settings']['port'], equals(443));

      final stream = proxy['streamSettings'] as Map<String, dynamic>;
      expect(stream['network'], equals('hysteria'));
      expect(stream['security'], equals('tls'));
      expect(stream['hysteriaSettings']['version'], equals(2));
      expect(stream['hysteriaSettings']['auth'], equals('auth-password'));
      expect(stream['tlsSettings']['serverName'], equals('example.com'));

      final masks = stream['finalmask']['udp'] as List;
      expect(masks.single['type'], equals('salamander'));
      expect(masks.single['settings']['password'], equals('obfs-secret'));
    });

    test('parses a plain link without obfs', () {
      final link = 'hy2://auth@example.com:24443?sni=example.com';

      final servers = parser.parseLines(link, 'sub');

      final stream = proxyOf(servers.single.configJson)['streamSettings'];
      expect(stream.containsKey('finalmask'), isFalse);
      expect(stream['hysteriaSettings']['auth'], equals('auth'));
    });

    test('converts a base64 pinSHA256 to hex for xray', () {
      final pin = base64.encode(List.generate(32, (i) => i));
      final link = 'hysteria2://auth@example.com:443?pinSHA256=$pin';

      final servers = parser.parseLines(link, 'sub');

      final stream = proxyOf(servers.single.configJson)['streamSettings'];
      expect(
        stream['tlsSettings']['pinnedPeerCertSha256'],
        equals(
          '000102030405060708090a0b0c0d0e0f'
          '101112131415161718191a1b1c1d1e1f',
        ),
      );
    });

    test('keeps a plus sign in a base64 pinSHA256', () {
      final pin = base64.encode([0xfb, ...List.generate(31, (i) => i)]);
      expect(pin, contains('+'));
      final link = 'hysteria2://auth@example.com:443?pinSHA256=$pin';

      final servers = parser.parseLines(link, 'sub');

      final stream = proxyOf(servers.single.configJson)['streamSettings'];
      expect(
        stream['tlsSettings']['pinnedPeerCertSha256'],
        equals(
          'fb000102030405060708090a0b0c0d0e0f'
          '101112131415161718191a1b1c1d1e',
        ),
      );
    });

    test('keeps a plus sign in the obfs password', () {
      final link =
          'hysteria2://auth@example.com:443'
          '?obfs=salamander&obfs-password=sec+ret';

      final servers = parser.parseLines(link, 'sub');

      final stream = proxyOf(servers.single.configJson)['streamSettings'];
      final masks = stream['finalmask']['udp'] as List;
      expect(masks.single['settings']['password'], equals('sec+ret'));
    });

    test('never emits allowInsecure even when insecure=1', () {
      final link = 'hysteria2://auth@example.com:443?insecure=1';

      final servers = parser.parseLines(link, 'sub');

      expect(servers.single.configJson, isNot(contains('allowInsecure')));
    });

    test('maps mport to udp port hopping', () {
      final link = 'hysteria2://auth@example.com:443?mport=20000-50000';

      final servers = parser.parseLines(link, 'sub');

      final stream = proxyOf(servers.single.configJson)['streamSettings'];
      expect(
        stream['finalmask']['quicParams']['udpHop']['ports'],
        equals('20000-50000'),
      );
    });

    test('falls back to "address:port" as title when there is no fragment', () {
      final link = 'hysteria2://auth@example.com:443';

      final servers = parser.parseLines(link, 'sub');

      expect(servers.single.title, equals('example.com:443'));
    });

    test('skips a link with an out-of-range port', () {
      final servers = parser.parseLines(
        'hysteria2://auth@example.com:70000',
        'sub',
      );

      expect(servers, isEmpty);
    });

    test('skips a link without auth', () {
      final servers = parser.parseLines('hysteria2://@example.com:443', 'sub');

      expect(servers, isEmpty);
    });
  });
}
