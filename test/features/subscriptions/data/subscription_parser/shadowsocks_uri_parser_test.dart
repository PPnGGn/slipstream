import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/country_code_extractor.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/shadowsocks_uri_parser.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/xray_config_builder.dart';

void main() {
  final parser = ShadowsocksUriParser(
    Talker(),
    XrayConfigBuilder(),
    CountryCodeExtractor(),
  );

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

  group('ShadowsocksUriParser.isShadowsocks', () {
    test('returns true for a plain ss:// link', () {
      expect(parser.isShadowsocks('ss://abc@host:8388'), isTrue);
    });

    test('returns true regardless of scheme casing', () {
      expect(parser.isShadowsocks('SS://abc@host:8388'), isTrue);
    });

    test('returns true when the link has surrounding whitespace', () {
      expect(parser.isShadowsocks('   ss://abc@host:8388   '), isTrue);
    });

    test('returns false for a vless scheme', () {
      expect(parser.isShadowsocks('vless://uuid@host:443'), isFalse);
    });

    test('returns false for an empty string', () {
      expect(parser.isShadowsocks(''), isFalse);
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

    test('ignores a plugin path/query on the host part', () {
      final link = sip002(
        'aes-256-gcm',
        'pw',
        'example.com:8388',
      ).replaceFirst('example.com:8388', 'example.com:8388/?plugin=obfs-local');

      final servers = parser.parseLines(link, 'sub');

      expect(servers.single.id, equals('example.com:8388:aes-256-gcm:#0'));
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
