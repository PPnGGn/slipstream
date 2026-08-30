import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/custom_json_parser.dart';

void main() {
  final parser = CustomJsonParser(Talker());

  group('CustomJsonParser.parse', () {
    test('parses the vnext outbound shape and fills every field', () {
      final json = jsonEncode([
        {
          'remarks': '🇩🇪 Germany #1',
          'outbounds': [
            {
              'tag': 'proxy',
              'protocol': 'vless',
              'settings': {
                'vnext': [
                  {
                    'address': 'vnext.example.com',
                    'port': 443,
                    'users': [
                      {'id': 'uuid-vnext'},
                    ],
                  },
                ],
              },
            },
            {'tag': 'direct', 'protocol': 'freedom', 'settings': {}},
          ],
        },
      ]);

      final servers = parser.parse(json, 'my-subscription');

      expect(servers, hasLength(1));
      final server = servers.first;
      expect(server.id, equals('vnext.example.com:443:uuid-vnext:#0'));
      expect(server.subscriptionId, equals('my-subscription'));
      expect(server.title, equals('🇩🇪 Germany #1'));
      expect(server.countryCode, equals('DE'));
    });

    test('parses the flat address outbound shape with a string port', () {
      final json = jsonEncode([
        {
          'remarks': 'Flat Server',
          'outbounds': [
            {
              'tag': 'proxy',
              'protocol': 'vless',
              'settings': {
                'address': 'flat.example.com',
                'port': '8443',
                'users': [
                  {'id': 'uuid-flat'},
                ],
              },
            },
          ],
        },
      ]);

      final servers = parser.parse(json, 'my-subscription');

      expect(servers.single.id, equals('flat.example.com:8443:uuid-flat:#0'));
    });

    test('matches outbound tags starting with "proxy-"', () {
      final json = jsonEncode([
        {
          'remarks': 'Server',
          'outbounds': [
            {
              'tag': 'proxy-1',
              'settings': {
                'address': 'host.example.com',
                'port': 443,
                'users': [
                  {'id': 'uuid'},
                ],
              },
            },
          ],
        },
      ]);

      final servers = parser.parse(json, 'my-subscription');

      expect(servers, hasLength(1));
    });

    test('skips an object with no proxy outbound at all', () {
      final json = jsonEncode([
        {
          'remarks': 'No Proxy Here',
          'outbounds': [
            {'tag': 'direct', 'settings': {}},
            {'tag': 'block', 'settings': {}},
          ],
        },
      ]);

      final servers = parser.parse(json, 'my-subscription');

      expect(servers, isEmpty);
    });

    test('skips objects with an invalid or out-of-range port', () {
      final json = jsonEncode([
        _serverWithPort(0),
        _serverWithPort(70000),
        {
          'remarks': 'Bad',
          'outbounds': [
            {
              'tag': 'proxy',
              'settings': {'address': 'host.example.com', 'port': 'abc'},
            },
          ],
        },
      ]);

      final servers = parser.parse(json, 'my-subscription');

      expect(servers, isEmpty);
    });

    test('defaults the title to "Unknown Server" when remarks is missing', () {
      final json = jsonEncode([
        {
          'outbounds': [
            {
              'tag': 'proxy',
              'settings': {
                'address': 'host.example.com',
                'port': 443,
                'users': [
                  {'id': 'uuid'},
                ],
              },
            },
          ],
        },
      ]);

      final servers = parser.parse(json, 'my-subscription');

      expect(servers.single.title, equals('Unknown Server'));
    });

    test('builds id without a uuid segment when users is empty', () {
      final json = jsonEncode([
        {
          'remarks': 'No Users',
          'outbounds': [
            {
              'tag': 'proxy',
              'settings': {
                'address': 'host.example.com',
                'port': 443,
                'users': [],
              },
            },
          ],
        },
      ]);

      final servers = parser.parse(json, 'my-subscription');

      expect(servers.single.id, equals('host.example.com:443:#0'));
    });

    test('skips a broken object but keeps the valid ones around it', () {
      final json = jsonEncode([
        {
          'remarks': 'Valid One',
          'outbounds': [
            {
              'tag': 'proxy',
              'settings': {
                'address': 'host.example.com',
                'port': 443,
                'users': [
                  {'id': 'uuid'},
                ],
              },
            },
          ],
        },
        {'remarks': 'Broken, no outbounds key at all'},
      ]);

      final servers = parser.parse(json, 'my-subscription');

      expect(servers, hasLength(1));
      expect(servers.single.title, equals('Valid One'));
    });

    test('accepts a single top-level object (not wrapped in an array)', () {
      final json = jsonEncode({
        'remarks': 'Single Object',
        'outbounds': [
          {
            'tag': 'proxy',
            'settings': {
              'address': 'host.example.com',
              'port': 443,
              'users': [
                {'id': 'uuid'},
              ],
            },
          },
        ],
      });

      final servers = parser.parse(json, 'my-subscription');

      expect(servers.single.title, equals('Single Object'));
    });

    test(
      'strips geosite:/geoip: entries (unresolvable without geosite.dat)',
      () {
        final json = jsonEncode([
          {
            'remarks': 'Server',
            'outbounds': [
              {
                'tag': 'proxy',
                'settings': {
                  'address': 'host.example.com',
                  'port': 443,
                  'users': [
                    {'id': 'uuid'},
                  ],
                },
              },
            ],
            'routing': {
              'rules': [
                {
                  'type': 'field',
                  'outboundTag': 'direct',
                  'domain': ['geosite:category-ru', 'domain:example.com'],
                },
                {
                  'type': 'field',
                  'outboundTag': 'direct',
                  'ip': ['geoip:cn', '10.0.0.0/8'],
                },
                {
                  'type': 'field',
                  'outboundTag': 'block',
                  'domain': ['geosite:category-ads'],
                },
                {
                  'type': 'field',
                  'outboundTag': 'direct',
                  'protocol': ['bittorrent'],
                },
              ],
            },
          },
        ]);

        final servers = parser.parse(json, 'my-subscription');
        final routing =
            jsonDecode(servers.single.configJson)['routing']
                as Map<String, dynamic>;
        final rules = (routing['rules'] as List).cast<Map<String, dynamic>>();

        expect(rules, hasLength(3));
        expect(rules[0]['domain'], equals(['domain:example.com']));
        expect(rules[1]['ip'], equals(['10.0.0.0/8']));
        expect(rules[2]['protocol'], equals(['bittorrent']));
      },
    );
  });

  group('CustomJsonParser routing sanitization', () {
    String fleetEntry() => jsonEncode([
      {
        'remarks': 'NL #1',
        'outbounds': [
          {
            'tag': 'proxy',
            'protocol': 'vless',
            'settings': {
              'vnext': [
                {
                  'address': '45.195.111.15',
                  'port': 443,
                  'users': [
                    {'id': 'uuid-1'},
                  ],
                },
              ],
            },
          },
          {'tag': 'direct', 'protocol': 'freedom', 'settings': {}},
          {'tag': 'block', 'protocol': 'blackhole', 'settings': {}},
        ],
        'observatory': {
          'subjectSelector': ['proxy'],
          'probeUrl': 'http://www.gstatic.com/generate_204',
        },
        'burstObservatory': {
          'subjectSelector': ['proxy'],
        },
        'routing': {
          'balancers': [
            {
              'tag': 'balancer',
              'selector': ['proxy'],
            },
          ],
          'rules': [
            {
              'type': 'field',
              'ip': ['45.195.111.15'],
              'outboundTag': 'proxy-45-195-111-15-direct',
            },
            {
              'type': 'field',
              'ip': ['45.198.96.153'],
              'outboundTag': 'proxy-45-198-96-153-direct',
            },
            {'type': 'field', 'network': 'tcp,udp', 'balancerTag': 'balancer'},
            {
              'type': 'field',
              'protocol': ['bittorrent'],
              'outboundTag': 'direct',
            },
          ],
        },
      },
    ]);

    Map<String, dynamic> configOf(String rawJson) =>
        jsonDecode(parser.parse(rawJson, 'sub').single.configJson)
            as Map<String, dynamic>;

    Set<String> outboundTagsOf(Map<String, dynamic> config) =>
        (config['outbounds'] as List)
            .map((o) => (o as Map<String, dynamic>)['tag'] as String)
            .toSet();

    test('drops routing rules that reference a non-existent outbound tag', () {
      final config = configOf(fleetEntry());
      final rules = (config['routing']['rules'] as List)
          .cast<Map<String, dynamic>>();
      final referenced = rules
          .map((r) => r['outboundTag'])
          .whereType<String>()
          .toSet();

      expect(referenced.difference(outboundTagsOf(config)), isEmpty);
      expect(referenced, contains('direct'));
      expect(referenced, isNot(contains('proxy-45-195-111-15-direct')));
      expect(referenced, isNot(contains('proxy-45-198-96-153-direct')));
    });

    test('removes observatory and burstObservatory', () {
      final config = configOf(fleetEntry());
      expect(config.containsKey('observatory'), isFalse);
      expect(config.containsKey('burstObservatory'), isFalse);
    });

    test('removes balancers and drops rules bound to them', () {
      final config = configOf(fleetEntry());
      expect(config['routing'].containsKey('balancers'), isFalse);
      final rules = (config['routing']['rules'] as List)
          .cast<Map<String, dynamic>>();
      expect(rules.any((r) => r.containsKey('balancerTag')), isFalse);
    });

    test('keeps proxy first so unmatched traffic defaults to it', () {
      final config = configOf(fleetEntry());
      final outbounds = (config['outbounds'] as List)
          .cast<Map<String, dynamic>>();
      expect(outbounds.first['tag'], equals('proxy'));
    });

    test('synthesizes direct/block when the subscription omits them', () {
      final json = jsonEncode([
        {
          'remarks': 'Bare',
          'outbounds': [
            {
              'tag': 'proxy',
              'protocol': 'vless',
              'settings': {
                'vnext': [
                  {
                    'address': 'host.example.com',
                    'port': 443,
                    'users': [
                      {'id': 'uuid'},
                    ],
                  },
                ],
              },
            },
          ],
        },
      ]);

      expect(outboundTagsOf(configOf(json)), containsAll(['direct', 'block']));
    });

    test('repoints rules referencing the original proxy tag to "proxy"', () {
      final json = jsonEncode([
        {
          'remarks': 'Renamed',
          'outbounds': [
            {
              'tag': 'proxy-1',
              'protocol': 'vless',
              'settings': {
                'vnext': [
                  {
                    'address': 'host.example.com',
                    'port': 443,
                    'users': [
                      {'id': 'uuid'},
                    ],
                  },
                ],
              },
            },
          ],
          'routing': {
            'rules': [
              {
                'type': 'field',
                'domain': ['domain:example.com'],
                'outboundTag': 'proxy-1',
              },
            ],
          },
        },
      ]);

      final rules = (configOf(json)['routing']['rules'] as List)
          .cast<Map<String, dynamic>>();
      expect(rules.single['outboundTag'], equals('proxy'));
    });
  });
}

Map<String, dynamic> _serverWithPort(int port) => {
  'remarks': 'Bad Port $port',
  'outbounds': [
    {
      'tag': 'proxy',
      'settings': {
        'address': 'host.example.com',
        'port': port,
        'users': [
          {'id': 'uuid'},
        ],
      },
    },
  ],
};
