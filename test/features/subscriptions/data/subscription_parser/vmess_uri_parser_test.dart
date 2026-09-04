import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/vmess_uri_parser.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/xray_config_builder.dart';

void main() {
  final parser = VmessUriParser(Talker(), XrayConfigBuilder());

  String vmessLink(Map<String, dynamic> payload) =>
      'vmess://${base64.encode(utf8.encode(jsonEncode(payload)))}';

  group('VmessUriParser.matches', () {
    test('returns true for a vmess:// link', () {
      expect(parser.matches('vmess://eyJ2IjoiMiJ9'), isTrue);
    });

    test('returns true regardless of scheme casing', () {
      expect(parser.matches('VMESS://eyJ2IjoiMiJ9'), isTrue);
    });

    test('returns false for another scheme', () {
      expect(parser.matches('vless://uuid@host:443'), isFalse);
    });
  });

  group('VmessUriParser.parseLines', () {
    test('parses a ws+tls link and fills every field', () {
      final link = vmessLink({
        'v': '2',
        'ps': '🇳🇱 Netherlands #1',
        'add': 'example.com',
        'port': '443',
        'id': '11111111-1111-1111-1111-111111111111',
        'aid': '0',
        'scy': 'auto',
        'net': 'ws',
        'type': 'none',
        'host': 'cdn.example.com',
        'path': '/ws-path',
        'tls': 'tls',
        'sni': 'cdn.example.com',
      });

      final servers = parser.parseLines(link, 'my-subscription');

      expect(servers, hasLength(1));
      final server = servers.single;
      expect(
        server.id,
        equals('example.com:443:11111111-1111-1111-1111-111111111111:#0'),
      );
      expect(server.subscriptionId, equals('my-subscription'));
      expect(server.title, equals('🇳🇱 Netherlands #1'));
      expect(server.countryCode, equals('NL'));

      final json = jsonDecode(server.configJson) as Map<String, dynamic>;
      final proxy = (json['outbounds'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((o) => o['tag'] == 'proxy');
      expect(proxy['protocol'], equals('vmess'));
      final user = proxy['settings']['vnext'][0]['users'][0];
      expect(user['id'], equals('11111111-1111-1111-1111-111111111111'));
      expect(user['alterId'], equals(0));
      expect(user['security'], equals('auto'));
      final stream = proxy['streamSettings'] as Map<String, dynamic>;
      expect(stream['network'], equals('ws'));
      expect(stream['security'], equals('tls'));
      expect(stream['wsSettings']['path'], equals('/ws-path'));
      expect(stream['wsSettings']['headers']['Host'], 'cdn.example.com');
      expect(stream['tlsSettings']['serverName'], equals('cdn.example.com'));
    });

    test('parses a plain tcp link without tls', () {
      final link = vmessLink({
        'ps': 'plain',
        'add': '1.2.3.4',
        'port': '10086',
        'id': '11111111-1111-1111-1111-111111111111',
        'aid': '64',
        'net': 'tcp',
        'tls': '',
      });

      final servers = parser.parseLines(link, 'sub');

      final json = jsonDecode(servers.single.configJson);
      final proxy = (json['outbounds'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((o) => o['tag'] == 'proxy');
      expect(proxy['streamSettings']['security'], equals('none'));
      expect(proxy['streamSettings'].containsKey('tlsSettings'), isFalse);
      expect(proxy['settings']['vnext'][0]['users'][0]['alterId'], 64);
    });

    test('maps path to serviceName for grpc', () {
      final link = vmessLink({
        'ps': 'grpc',
        'add': 'example.com',
        'port': '443',
        'id': '11111111-1111-1111-1111-111111111111',
        'net': 'grpc',
        'path': 'my-service',
        'tls': 'tls',
      });

      final servers = parser.parseLines(link, 'sub');

      final json = jsonDecode(servers.single.configJson);
      final proxy = (json['outbounds'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((o) => o['tag'] == 'proxy');
      expect(
        proxy['streamSettings']['grpcSettings']['serviceName'],
        equals('my-service'),
      );
    });

    test('falls back to "address:port" as title when ps is empty', () {
      final link = vmessLink({
        'ps': '',
        'add': 'example.com',
        'port': '443',
        'id': '11111111-1111-1111-1111-111111111111',
        'net': 'tcp',
      });

      final servers = parser.parseLines(link, 'sub');

      expect(servers.single.title, equals('example.com:443'));
    });

    test('skips a link with broken base64', () {
      final servers = parser.parseLines('vmess://!!!not-base64!!!', 'sub');

      expect(servers, isEmpty);
    });

    test('skips a link with non-JSON payload', () {
      final link = 'vmess://${base64.encode(utf8.encode('not json'))}';

      final servers = parser.parseLines(link, 'sub');

      expect(servers, isEmpty);
    });

    test('skips a link without id', () {
      final link = vmessLink({'add': 'example.com', 'port': '443'});

      final servers = parser.parseLines(link, 'sub');

      expect(servers, isEmpty);
    });

    test('skips a link with an out-of-range port', () {
      final link = vmessLink({
        'add': 'example.com',
        'port': '70000',
        'id': '11111111-1111-1111-1111-111111111111',
      });

      final servers = parser.parseLines(link, 'sub');

      expect(servers, isEmpty);
    });
  });
}
