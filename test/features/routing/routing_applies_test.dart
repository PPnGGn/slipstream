import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/routing/data/routing_applies.dart';

void main() {
  VpnServer server(Map<String, dynamic> config) => VpnServer(
    id: 's',
    subscriptionId: 'sub',
    countryCode: 'DE',
    title: 'Server',
    configJson: jsonEncode(config),
  );

  final scaffold = {
    'outbounds': [
      {'tag': 'proxy', 'protocol': 'vless'},
    ],
    'routing': {
      'rules': [
        {
          'type': 'field',
          'protocol': ['bittorrent'],
          'outboundTag': 'direct',
        },
      ],
    },
  };

  final provider = {
    'outbounds': [
      {'tag': 'p', 'protocol': 'vless'},
    ],
    'routing': {
      'rules': [
        {
          'type': 'field',
          'domain': ['geosite:ru'],
          'outboundTag': 'direct',
        },
      ],
    },
  };

  test('no server chosen — nothing to warn about', () {
    expect(routingAppliesTo(null), isTrue);
  });

  test('a config without a routing of its own takes the settings', () {
    expect(routingAppliesTo(server(scaffold)), isTrue);
  });

  test('a provider config with its own routing does not', () {
    expect(routingAppliesTo(server(provider)), isFalse);
  });
}
