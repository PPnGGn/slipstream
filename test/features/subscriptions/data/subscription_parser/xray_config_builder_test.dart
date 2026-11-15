import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/vless_uri_parser.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/xray_config_builder.dart';

void main() {
  final parser = VlessUriParser(Talker(), XrayConfigBuilder());

  Map<String, dynamic> directOutboundOf(String link) {
    final config =
        jsonDecode(parser.parseLines(link, 'sub').single.configJson)
            as Map<String, dynamic>;
    return (config['outbounds'] as List).cast<Map<String, dynamic>>().firstWhere(
      (o) => o['tag'] == 'direct',
    );
  }

  group('XrayConfigBuilder direct outbound', () {
    const link = 'vless://11111111-1111-1111-1111-111111111111@example.com:443'
        '?sni=example.com&pbk=publicKey123&sid=abcd&fp=firefox#Server';

    test('resolves domains through sockopt, the current field', () {
      final direct = directOutboundOf(link);

      expect(direct['streamSettings']['sockopt']['domainStrategy'], 'UseIP');
    });

    test('does not use the deprecated freedom.domainStrategy', () {
      // xray logs a deprecation warning at every start for this field.
      final direct = directOutboundOf(link);

      final settings = (direct['settings'] as Map?) ?? const {};
      expect(settings.containsKey('domainStrategy'), isFalse);
    });
  });
}
