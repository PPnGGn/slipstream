import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/shadowsocks_uri_parser.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/xray_config_builder.dart';

void main() {
  final parser = ShadowsocksUriParser(Talker(), XrayConfigBuilder());

  String sip002(
    String method,
    String password,
    String hostPort, {
    String? tag,
  }) {
    final userInfo = base64Url.encode(utf8.encode('$method:$password'));
    final base = 'ss://$userInfo@$hostPort';
    return tag == null ? base : '$base#${Uri.encodeComponent(tag)}';
  }

  group('ShadowsocksUriParser.matches', () {
    test('returns true for a plain ss:// link', () {
      expect(parser.matches('ss://abc@host:8388'), isTrue);
    });

    test('returns true regardless of scheme casing', () {
      expect(parser.matches('SS://abc@host:8388'), isTrue);
    });

    test('returns true when the link has surrounding whitespace', () {
      expect(parser.matches('   ss://abc@host:8388   '), isTrue);
    });

    test('returns false for a vless scheme', () {
      expect(parser.matches('vless://uuid@host:443'), isFalse);
    });

    test('returns false for an empty string', () {
      expect(parser.matches(''), isFalse);
    });
  });

  group('ShadowsocksUriParser.parseLines', () {
    test('parses a SIP002 link and fills every field', () {
      final link = sip002(
        'aes-256-gcm',
        'mypassword',
        'example.com:8388',
        tag: '🇳🇱 Netherlands #1',
      );

      final servers = parser.parseLines(link, 'my-subscription');

      expect(servers, hasLength(1));
      final server = servers.single;
      expect(server.id, equals('example.com:8388:aes-256-gcm:#0'));
      expect(server.subscriptionId, equals('my-subscription'));
      expect(server.title, equals('🇳🇱 Netherlands #1'));
      expect(server.countryCode, equals('NL'));
      expect(server.configJson, contains('"protocol":"shadowsocks"'));
      expect(server.configJson, contains('"method":"aes-256-gcm"'));
      expect(server.configJson, contains('"password":"mypassword"'));
      expect(server.configJson, contains('"address":"example.com"'));
    });

    test('parses a legacy base64 link (method:pass@host:port)', () {
      final payload = base64.encode(
        utf8.encode('chacha20-ietf-poly1305:secret@1.2.3.4:443'),
      );
      final link = 'ss://$payload#Legacy';

      final servers = parser.parseLines(link, 'sub');

      expect(servers, hasLength(1));
      final server = servers.single;
      expect(server.id, equals('1.2.3.4:443:chacha20-ietf-poly1305:#0'));
      expect(server.title, equals('Legacy'));
      expect(server.configJson, contains('"password":"secret"'));
    });

    test('accepts percent-encoded (non-base64) userinfo', () {
      final link = 'ss://aes-256-gcm:p%40ss@example.com:8388#Plain';

      final servers = parser.parseLines(link, 'sub');

      expect(servers.single.configJson, contains('"password":"p@ss"'));
    });

    test('skips a link whose plugin xray cannot replace with a transport', () {
      final link = sip002(
        'aes-256-gcm',
        'pw',
        'example.com:8388',
      ).replaceFirst('example.com:8388', 'example.com:8388/?plugin=obfs-local');

      final servers = parser.parseLines(link, 'sub');

      expect(servers, isEmpty);
    });

    test('translates v2ray-plugin websocket into ws streamSettings', () {
      final plugin = Uri.encodeComponent(
        'v2ray-plugin;tls;mode=websocket;host=cdn.example.com;path=/vpn',
      );
      final link = sip002(
        'aes-256-gcm',
        'pw',
        'example.com:8388',
      ).replaceFirst('example.com:8388', 'example.com:8388/?plugin=$plugin');

      final servers = parser.parseLines(link, 'sub');

      final stream = _streamSettingsOf(servers.single.configJson);
      expect(stream['network'], equals('ws'));
      expect(stream['security'], equals('tls'));
      expect(stream['wsSettings']['path'], equals('/vpn'));
      expect(
        stream['wsSettings']['headers']['Host'],
        equals('cdn.example.com'),
      );
      expect(stream['tlsSettings']['serverName'], equals('cdn.example.com'));
    });

    test('translates obfs-local http into the tcp http header', () {
      final plugin = Uri.encodeComponent(
        'obfs-local;obfs=http;obfs-host=www.bing.com',
      );
      final link = sip002(
        'aes-256-gcm',
        'pw',
        'example.com:8388',
      ).replaceFirst('example.com:8388', 'example.com:8388/?plugin=$plugin');

      final servers = parser.parseLines(link, 'sub');

      final stream = _streamSettingsOf(servers.single.configJson);
      expect(stream['network'], equals('tcp'));
      final header = stream['tcpSettings']['header'];
      expect(header['type'], equals('http'));
      expect(header['request']['headers']['Host'], equals(['www.bing.com']));
      expect(header['request']['path'], equals(['/']));
    });

    test('builds a plain tcp config when there is no plugin', () {
      final link = sip002('aes-256-gcm', 'pw', 'example.com:8388');

      final servers = parser.parseLines(link, 'sub');

      final stream = _streamSettingsOf(servers.single.configJson);
      expect(stream['network'], equals('tcp'));
      expect(stream['security'], equals('none'));
    });

    test('falls back to "host:port" as title when there is no fragment', () {
      final link = sip002('aes-256-gcm', 'pw', 'example.com:8388');

      final servers = parser.parseLines(link, 'sub');

      expect(servers.single.title, equals('example.com:8388'));
    });

    test('skips a broken line but keeps the valid ones around it', () {
      final good = sip002('aes-256-gcm', 'pw', 'example.com:8388', tag: 'ok');
      final text = 'ss://@@@not-valid\n$good\nss://also-broken';

      final servers = parser.parseLines(text, 'sub');

      expect(servers, hasLength(1));
      expect(servers.single.title, equals('ok'));
    });
  });
}

Map<String, dynamic> _streamSettingsOf(String configJson) {
  final json = jsonDecode(configJson) as Map<String, dynamic>;
  final proxy = (json['outbounds'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((o) => o['tag'] == 'proxy');
  return (proxy['streamSettings'] as Map).cast<String, dynamic>();
}
