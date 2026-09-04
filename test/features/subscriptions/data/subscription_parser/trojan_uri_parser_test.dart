import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/trojan_uri_parser.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/xray_config_builder.dart';

void main() {
  final parser = TrojanUriParser(Talker(), XrayConfigBuilder());

  Map<String, dynamic> proxyOf(String configJson) {
    final json = jsonDecode(configJson) as Map<String, dynamic>;
    return (json['outbounds'] as List).cast<Map<String, dynamic>>().firstWhere(
      (o) => o['tag'] == 'proxy',
    );
  }

  group('TrojanUriParser.matches', () {
    test('returns true for a trojan:// link', () {
      expect(parser.matches('trojan://pw@host:443'), isTrue);
    });

    test('returns true regardless of scheme casing', () {
      expect(parser.matches('TROJAN://pw@host:443'), isTrue);
    });

    test('returns false for another scheme', () {
      expect(parser.matches('ss://pw@host:443'), isFalse);
    });
  });

  group('TrojanUriParser.parseLines', () {
    test('parses a ws+tls link and fills every field', () {
      final link =
          'trojan://secret@example.com:443'
          '?security=tls&sni=cdn.example.com&type=ws'
          '&path=%2Ftrojan&host=cdn.example.com'
          '#%F0%9F%87%B3%F0%9F%87%B1%20Netherlands%20%231';

      final servers = parser.parseLines(link, 'my-subscription');

      expect(servers, hasLength(1));
      final server = servers.single;
      expect(server.id, equals('example.com:443:secret:#0'));
      expect(server.subscriptionId, equals('my-subscription'));
      expect(server.title, equals('🇳🇱 Netherlands #1'));
      expect(server.countryCode, equals('NL'));

      final proxy = proxyOf(server.configJson);
      expect(proxy['protocol'], equals('trojan'));
      expect(proxy['settings']['servers'][0]['password'], equals('secret'));
      expect(proxy['settings']['servers'][0]['address'], 'example.com');
      final stream = proxy['streamSettings'] as Map<String, dynamic>;
      expect(stream['security'], equals('tls'));
      expect(stream['network'], equals('ws'));
      expect(stream['wsSettings']['path'], equals('/trojan'));
      expect(stream['tlsSettings']['serverName'], equals('cdn.example.com'));
    });

    test('defaults to tls over tcp when there are no params', () {
      final link = 'trojan://secret@example.com:443';

      final servers = parser.parseLines(link, 'sub');

      final stream = proxyOf(servers.single.configJson)['streamSettings'];
      expect(stream['security'], equals('tls'));
      expect(stream['network'], equals('tcp'));
    });

    test('decodes a percent-encoded password', () {
      final link = 'trojan://p%40ss%23word@example.com:443';

      final servers = parser.parseLines(link, 'sub');

      final proxy = proxyOf(servers.single.configJson);
      expect(proxy['settings']['servers'][0]['password'], equals('p@ss#word'));
    });

    test('falls back to "address:port" as title when there is no fragment', () {
      final link = 'trojan://secret@example.com:443';

      final servers = parser.parseLines(link, 'sub');

      expect(servers.single.title, equals('example.com:443'));
    });

    test('skips a link with an out-of-range port', () {
      final servers = parser.parseLines(
        'trojan://secret@example.com:70000',
        'sub',
      );

      expect(servers, isEmpty);
    });

    test('skips a link without a password', () {
      final servers = parser.parseLines('trojan://@example.com:443', 'sub');

      expect(servers, isEmpty);
    });

    test('skips a link with an unknown network type', () {
      final servers = parser.parseLines(
        'trojan://secret@example.com:443?type=quic',
        'sub',
      );

      expect(servers, isEmpty);
    });
  });
}
