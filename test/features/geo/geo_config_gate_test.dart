import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/geo/cubit/geo_cubit.dart';
import 'package:slipstream/features/geo/data/geo_catalog.dart';
import 'package:slipstream/features/geo/data/geo_config_gate.dart';

void main() {
  final gate = GeoConfigGate(Talker());

  GeoState ready(Set<String> site, Set<String> ip) => GeoState.ready(
    catalog: GeoCatalog(site: site, ip: ip),
    tag: 't',
    updatedAt: DateTime(2026),
  );

  Map<String, dynamic> run(Map<String, dynamic> config, GeoState geo) =>
      jsonDecode(gate.prepare(jsonEncode(config), geo)) as Map<String, dynamic>;

  const proxyOnly = {
    'outbounds': [
      {'tag': 'proxy', 'protocol': 'freedom'},
    ],
  };

  group('GeoConfigGate — geo not installed', () {
    final absent = const GeoState.absent();

    test('strips every geosite:/geoip: token from dns and routing', () {
      final result = run({
        ...proxyOnly,
        'dns': {
          'hosts': {
            'geosite:category-ads': ['127.0.0.1'],
            'real.example.com': ['1.2.3.4'],
          },
          'servers': [
            '8.8.8.8',
            {
              'address': '77.88.8.8',
              'domains': ['geosite:category-ru', 'geosite:category-gov-ru'],
            },
            {
              'address': '1.1.1.1',
              'domains': ['geosite:x', 'domain:keep.example.com'],
              'expectIPs': ['geoip:ru', '9.9.9.9/32'],
            },
          ],
        },
        'routing': {
          'rules': [
            {'outboundTag': 'direct', 'domain': ['geosite:category-ru', 'domain:a.com']},
            {'outboundTag': 'direct', 'ip': ['geoip:cn', '10.0.0.0/8']},
            {'outboundTag': 'block', 'domain': ['geosite:category-ads']},
            {'outboundTag': 'direct', 'protocol': ['bittorrent']},
          ],
        },
      }, absent);

      expect(jsonEncode(result), isNot(contains('geosite:')));
      expect(jsonEncode(result), isNot(contains('geoip:')));

      final servers = result['dns']['servers'] as List;
      // string server kept, geo-only server dropped, mixed server keeps the rest
      expect(servers, hasLength(2));
      expect(servers[0], '8.8.8.8');
      expect(servers[1]['domains'], ['domain:keep.example.com']);
      expect(servers[1]['expectIPs'], ['9.9.9.9/32']);
      expect((result['dns']['hosts'] as Map).keys, ['real.example.com']);

      final rules = (result['routing']['rules'] as List).cast<Map>();
      // rule with only geosite:category-ads had nothing left -> dropped
      expect(rules, hasLength(3));
      expect(rules[0]['domain'], ['domain:a.com']);
      expect(rules[1]['ip'], ['10.0.0.0/8']);
      expect(rules[2]['protocol'], ['bittorrent']);
    });

    test('all DNS servers scoped to geo -> fallback resolver injected', () {
      final result = run({
        ...proxyOnly,
        'dns': {
          'servers': [
            {'address': '77.88.8.8', 'domains': ['geosite:category-ru']},
          ],
        },
      }, absent);

      expect(result['dns']['servers'], ['1.1.1.1', '8.8.8.8']);
    });

    test('config with no geo refs comes back byte-identical', () {
      const src =
          '{"outbounds":[{"tag":"proxy"}],"routing":{"rules":[{"outboundTag":"direct","domain":["domain:a.com"]}]}}';
      expect(gate.prepare(src, absent), same(src));
    });

    // Each of these mirrors a field xray-core actually routes through
    // geodata.ParseDomainRules/ParseIPRules (infra/conf/router.go, dns.go,
    // xray.go) but that earlier versions of this gate didn't touch — verified
    // against a real buildCoreConfig() with an empty asset dir, each one
    // failed with "failed to open geosite.dat"/"geoip.dat" before the gate
    // covered it. A regression here means a provider config using that field
    // fails to connect instead of degrading to a stripped route.
    group('every routing/dns/sniffing field xray resolves through geodata', () {
      test('routing.rules[].domains (plural alias of domain)', () {
        final result = run({
          ...proxyOnly,
          'routing': {
            'rules': [
              {
                'outboundTag': 'direct',
                'domains': ['geosite:category-ru', 'domain:a.com'],
              },
            ],
          },
        }, absent);

        final rule = (result['routing']['rules'] as List).first as Map;
        expect(rule['domains'], ['domain:a.com']);
      });

      test('routing.rules[].source', () {
        final result = run({
          ...proxyOnly,
          'routing': {
            'rules': [
              {'outboundTag': 'direct', 'source': ['geoip:ru', '10.0.0.0/8']},
            ],
          },
        }, absent);

        final rule = (result['routing']['rules'] as List).first as Map;
        expect(rule['source'], ['10.0.0.0/8']);
      });

      test('routing.rules[].sourceIP', () {
        final result = run({
          ...proxyOnly,
          'routing': {
            'rules': [
              {'outboundTag': 'direct', 'sourceIP': ['geoip:ru', '10.0.0.0/8']},
            ],
          },
        }, absent);

        final rule = (result['routing']['rules'] as List).first as Map;
        expect(rule['sourceIP'], ['10.0.0.0/8']);
      });

      test('routing.rules[].localIP', () {
        final result = run({
          ...proxyOnly,
          'routing': {
            'rules': [
              {'outboundTag': 'direct', 'localIP': ['geoip:private', '127.0.0.1']},
            ],
          },
        }, absent);

        final rule = (result['routing']['rules'] as List).first as Map;
        expect(rule['localIP'], ['127.0.0.1']);
      });

      test('routing rule left with only a now-empty source/sourceIP/localIP is dropped', () {
        final result = run({
          ...proxyOnly,
          'routing': {
            'rules': [
              {'outboundTag': 'direct', 'sourceIP': ['geoip:ru']},
              {'outboundTag': 'direct', 'domain': ['domain:keep.com']},
            ],
          },
        }, absent);

        final rules = (result['routing']['rules'] as List).cast<Map>();
        expect(rules, hasLength(1));
        expect(rules.single['domain'], ['domain:keep.com']);
      });

      test('inbounds[].sniffing.domainsExcluded / ipsExcluded', () {
        final result = run({
          ...proxyOnly,
          'inbounds': [
            {
              'tag': 'socks',
              'protocol': 'socks',
              'sniffing': {
                'enabled': true,
                'destOverride': ['http', 'tls'],
                'domainsExcluded': ['geosite:category-ru', 'domain:a.com'],
                'ipsExcluded': ['geoip:private', '10.0.0.0/8'],
              },
            },
          ],
        }, absent);

        final sniffing = (result['inbounds'] as List).first['sniffing'] as Map;
        expect(sniffing['domainsExcluded'], ['domain:a.com']);
        expect(sniffing['ipsExcluded'], ['10.0.0.0/8']);
        // sniffing itself (enabled/destOverride) is never removed, even if
        // both excluded lists end up empty elsewhere.
        expect(sniffing['enabled'], true);
      });

      test('sniffing block with only geo exclusions keeps the block, empties the lists', () {
        final result = run({
          ...proxyOnly,
          'inbounds': [
            {
              'tag': 'socks',
              'sniffing': {
                'enabled': true,
                'domainsExcluded': ['geosite:category-ru'],
              },
            },
          ],
        }, absent);

        final sniffing = (result['inbounds'] as List).first['sniffing'] as Map;
        expect(sniffing.containsKey('domainsExcluded'), isFalse);
        expect(sniffing['enabled'], true);
      });

      test('dns.servers[].unexpectedIPs', () {
        final result = run({
          ...proxyOnly,
          'dns': {
            'servers': [
              {
                'address': '1.1.1.1',
                'unexpectedIPs': ['geoip:ru', '10.0.0.0/8'],
              },
            ],
          },
        }, absent);

        final server = (result['dns']['servers'] as List).first as Map;
        expect(server['unexpectedIPs'], ['10.0.0.0/8']);
      });

      test('kitchen sink — all six fields at once leave zero geo tokens behind', () {
        final result = run({
          ...proxyOnly,
          'inbounds': [
            {
              'tag': 'socks',
              'sniffing': {
                'enabled': true,
                'domainsExcluded': ['geosite:category-ru'],
                'ipsExcluded': ['geoip:ru'],
              },
            },
          ],
          'dns': {
            'servers': [
              {
                'address': '1.1.1.1',
                'unexpectedIPs': ['geoip:ru'],
              },
            ],
          },
          'routing': {
            'rules': [
              {
                'outboundTag': 'direct',
                'domains': ['geosite:category-ru'],
                'source': ['geoip:ru'],
                'sourceIP': ['geoip:private'],
                'localIP': ['geoip:private'],
              },
              {'outboundTag': 'direct', 'domain': ['domain:keep.example.com']},
            ],
          },
        }, absent);

        final json = jsonEncode(result);
        expect(json, isNot(contains('geosite:')));
        expect(json, isNot(contains('geoip:')));
        // the rule that had ONLY geo matchers is gone; the one with a
        // non-geo matcher survives.
        final rules = (result['routing']['rules'] as List).cast<Map>();
        expect(rules, hasLength(1));
        expect(rules.single['domain'], ['domain:keep.example.com']);
      });
    });

    test('dns.servers[].geoip is left alone (not a real NameServerConfig field)', () {
      // Regression guard: earlier versions of this gate special-cased a
      // `geoip` field on dns.servers[] that doesn't exist in this xray-core's
      // NameServerConfig (infra/conf/dns.go) — dead code, removed. Anything
      // literally named `geoip` on a server is just passed through untouched.
      const src = '{"outbounds":[{"tag":"proxy"}],'
          '"dns":{"servers":[{"address":"1.1.1.1","geoip":"whatever"}]}}';
      expect(gate.prepare(src, absent), same(src));
    });
  });

  group('GeoConfigGate — geo installed', () {
    test('keeps tokens present in the catalog, strips the rest', () {
      final result = run({
        ...proxyOnly,
        'routing': {
          'rules': [
            {
              'outboundTag': 'direct',
              'domain': ['geosite:category-ru', 'geosite:unknown', 'domain:a.com'],
            },
            {'outboundTag': 'direct', 'ip': ['geoip:ru', 'geoip:cn']},
          ],
        },
      }, ready({'geosite:category-ru'}, {'geoip:ru'}));

      final rules = (result['routing']['rules'] as List).cast<Map>();
      expect(rules[0]['domain'], ['geosite:category-ru', 'domain:a.com']);
      expect(rules[1]['ip'], ['geoip:ru']);
    });

    test('ext: / ext-ip: refs are dropped even when geo is installed', () {
      final result = run({
        ...proxyOnly,
        'routing': {
          'rules': [
            {
              'outboundTag': 'direct',
              'domain': ['ext:custom.dat:foo', 'geosite:category-ru'],
              'ip': ['ext-ip:custom.dat:bar', '1.1.1.1/32'],
            },
          ],
        },
      }, ready({'geosite:category-ru'}, const {}));

      final rule = (result['routing']['rules'] as List).first as Map;
      expect(rule['domain'], ['geosite:category-ru']);
      expect(rule['ip'], ['1.1.1.1/32']);
    });

    test('untouched config returns the same string instance', () {
      const src = '{"outbounds":[{"tag":"proxy"}],"routing":{"rules":['
          '{"outboundTag":"direct","domain":["geosite:category-ru"]}]}}';
      expect(gate.prepare(src, ready({'geosite:category-ru'}, const {})), same(src));
    });
  });
}
