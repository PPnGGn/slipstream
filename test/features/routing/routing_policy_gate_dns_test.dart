import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/dns/data/direct_dns.dart';
import 'package:slipstream/features/dns/data/dns_settings.dart';
import 'package:slipstream/features/dns/data/remote_dns.dart';
import 'package:slipstream/features/geo/cubit/geo_cubit.dart';
import 'package:slipstream/features/geo/data/geo_config_gate.dart';
import 'package:slipstream/features/routing/data/ad_block_mode.dart';
import 'package:slipstream/features/routing/data/routing_policy_gate.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';

/// What the DNS page changes in the config RoutingPolicyGate builds: the `dns`
/// block and the `dns-out` outbound. The rules around them are covered by
/// routing_policy_gate_test.dart and must not move.
void main() {
  final gate = RoutingPolicyGate(Talker());

  // XrayConfigBuilder._wrap() output: proxy + direct + block, no matchers.
  Map<String, dynamic> scaffold() => {
    'dns': {
      'servers': ['https://8.8.8.8/dns-query'],
    },
    'outbounds': [
      {'tag': 'proxy', 'protocol': 'vless'},
      {'tag': 'direct', 'protocol': 'freedom'},
      {'tag': 'block', 'protocol': 'blackhole'},
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

  PolicyResult applyTo(
    Map<String, dynamic> config, {
    DnsSettings dns = const DnsSettings(),
    bool ipv6 = false,
    RuBypassMode split = RuBypassMode.bypassRu,
  }) => gate.apply(
    jsonEncode(config),
    split: split,
    adBlock: AdBlockMode.off,
    dns: dns,
    ipv6: ipv6,
  );

  Map<String, dynamic> built({
    DnsSettings dns = const DnsSettings(),
    bool ipv6 = false,
    RuBypassMode split = RuBypassMode.bypassRu,
  }) =>
      jsonDecode(
            applyTo(scaffold(), dns: dns, ipv6: ipv6, split: split).configJson,
          )
          as Map<String, dynamic>;

  List<dynamic> serversOf(Map<String, dynamic> config) =>
      config['dns']['servers'] as List;

  Map<String, dynamic> server(Map<String, dynamic> config, String tag) =>
      serversOf(
        config,
      ).whereType<Map<String, dynamic>>().firstWhere((s) => s['tag'] == tag);

  List<String?> tagsOf(Map<String, dynamic> config) =>
      (config['routing']['rules'] as List)
          .map((r) => (r as Map)['ruleTag'] as String?)
          .toList();

  Map<String, dynamic> dnsOut(Map<String, dynamic> config) =>
      (config['outbounds'] as List).cast<Map<String, dynamic>>().firstWhere(
        (o) => o['tag'] == 'dns-out',
      );

  group('remote resolver', () {
    for (final remote in RemoteDns.values) {
      test('${remote.name}: dns-remote asks ${remote.address}', () {
        final config = built(dns: DnsSettings(remote: remote));
        expect(server(config, 'dns-remote')['address'], remote.address);
      });

      test('${remote.name}: its own queries are routed before any block', () {
        // The resolver's address is itself a "public DNS" the later rules
        // block; the dns-remote rule must win, or the resolver cannot answer.
        final tags = tagsOf(built(dns: DnsSettings(remote: remote)));
        expect(
          tags.indexOf('dns-remote'),
          lessThan(tags.indexOf('block-public-dns')),
        );
        expect(tags.indexOf('dns-remote'), lessThan(tags.indexOf('block-doh')));
        expect(
          tags.indexOf('dns-remote'),
          lessThan(tags.indexOf('dns-hijack')),
        );
      });
    }

    test('its queries still go through the proxy outbound', () {
      final config = built(dns: const DnsSettings(remote: RemoteDns.xray));
      final rule = (config['routing']['rules'] as List).cast<Map>().firstWhere(
        (r) => r['ruleTag'] == 'dns-remote',
      );
      expect(rule['inboundTag'], ['dns-remote']);
      expect(rule['outboundTag'], 'proxy');
    });
  });

  group('direct resolver', () {
    test('yandex: dns-ru asks the Yandex DoH', () {
      final ru = server(built(), 'dns-ru');
      expect(ru['address'], 'https://77.88.8.8/dns-query');
    });

    test('system: dns-ru asks localhost, scope and fallback stay', () {
      final ru = server(
        built(dns: const DnsSettings(direct: DirectDns.system)),
        'dns-ru',
      );
      expect(ru['address'], 'localhost');
      // Still only Russian names, still a Russian answer only, and still out
      // of the fallback round: if localhost fails, dns-remote answers.
      expect(ru['domains'], contains('domain:ru'));
      expect(ru['expectIPs'], ['geoip:ru']);
      expect(ru['skipFallback'], isTrue);
    });

    for (final direct in DirectDns.values) {
      test('${direct.name}: without the RU bypass there is no dns-ru', () {
        final config = built(
          dns: DnsSettings(direct: direct),
          split: RuBypassMode.off,
        );
        expect(serversOf(config).whereType<Map>().map((s) => s['tag']), [
          'dns-remote',
        ]);
        expect(tagsOf(config), isNot(contains('dns-ru')));
      });
    }
  });

  group('Fake DNS', () {
    test('on: the fakedns server answers first, the real ones follow', () {
      final config = built(dns: const DnsSettings(fakeDns: true));
      final servers = serversOf(config);
      expect(servers.first, 'fakedns');
      expect(servers.whereType<Map>().map((s) => s['tag']), [
        'dns-ru',
        'dns-remote',
      ]);
    });

    test('on, no RU bypass: fakedns then dns-remote', () {
      final config = built(
        dns: const DnsSettings(fakeDns: true),
        split: RuBypassMode.off,
      );
      expect(serversOf(config).first, 'fakedns');
      expect(serversOf(config).length, 2);
    });

    test('off: no fakedns server', () {
      expect(serversOf(built()), isNot(contains('fakedns')));
    });

    test('on: still hijacks the system DNS', () {
      expect(
        applyTo(scaffold(), dns: const DnsSettings(fakeDns: true)).hijacksDns,
        isTrue,
      );
    });

    test('on: no pool block, xray makes the pool from the query strategy', () {
      // xray adds the fake pool by itself when "fakedns" is among the
      // servers: IPv4 for UseIPv4, IPv4 and IPv6 for UseIP.
      final config = built(dns: const DnsSettings(fakeDns: true));
      expect(
        config.keys.map((k) => k.toLowerCase()),
        isNot(contains('fakedns')),
      );
    });

    test('on: the rules around the resolvers do not move', () {
      expect(
        tagsOf(built(dns: const DnsSettings(fakeDns: true))),
        tagsOf(built()),
      );
    });
  });

  group('IPv6', () {
    test('off: IPv4 answers only, AAAA and HTTPS dropped', () {
      final config = built();
      expect(config['dns']['queryStrategy'], 'UseIPv4');
      expect(dnsOut(config)['settings']['rules'], [
        {'action': 'return', 'qType': '28,65'},
      ]);
    });

    test('on: both families, only HTTPS dropped', () {
      final config = built(ipv6: true);
      expect(config['dns']['queryStrategy'], 'UseIP');
      expect(dnsOut(config)['settings']['rules'], [
        {'action': 'return', 'qType': '65'},
      ]);
    });

    test('on does not change the rules', () {
      expect(tagsOf(built(ipv6: true)), tagsOf(built()));
    });
  });

  group('defaults', () {
    test('give exactly the config the app built before the DNS page', () {
      final config = built();
      expect(config['dns'], {
        'servers': [
          {
            'tag': 'dns-ru',
            'address': 'https://77.88.8.8/dns-query',
            'domains': [
              'domain:ru',
              'domain:xn--p1ai',
              'geosite:category-ru',
              'geosite:category-gov-ru',
            ],
            'expectIPs': ['geoip:ru'],
            'skipFallback': true,
          },
          {'tag': 'dns-remote', 'address': 'https://8.8.8.8/dns-query'},
        ],
        'queryStrategy': 'UseIPv4',
      });
      expect(dnsOut(config)['settings']['rules'], [
        {'action': 'return', 'qType': '28,65'},
      ]);
    });
  });

  group('provider configs', () {
    Map<String, dynamic> provider() => {
      'dns': {
        'servers': [
          {
            'address': 'https://77.88.8.8/dns-query',
            'domains': ['domain:ru'],
          },
          'https://1.1.1.1/dns-query',
        ],
      },
      'outbounds': [
        {'tag': 'proxy', 'protocol': 'vless'},
        {'tag': 'direct', 'protocol': 'freedom'},
      ],
      'routing': {
        'rules': [
          {
            'domain': ['geosite:category-ru'],
            'outboundTag': 'direct',
          },
          {'network': 'tcp,udp', 'outboundTag': 'proxy'},
        ],
      },
    };

    const everything = DnsSettings(
      remote: RemoteDns.cloudflare,
      direct: DirectDns.system,
      fakeDns: true,
    );

    test('keep their own dns whatever the page says', () {
      final src = provider();
      final result = applyTo(src, dns: everything, ipv6: true);
      final config = jsonDecode(result.configJson) as Map<String, dynamic>;
      expect(config['dns'], src['dns']);
      // Only the port-53 hijack is added, as before.
      expect(result.hijacksDns, isTrue);
      expect(
        (config['routing']['rules'] as List).first['ruleTag'],
        'dns-hijack',
      );
    });

    test('without a routed resolver they stay untouched', () {
      final src = provider()
        ..['dns'] = {
          'servers': ['localhost'],
        };
      final text = jsonEncode(src);
      final result = gate.apply(
        text,
        split: RuBypassMode.bypassRu,
        adBlock: AdBlockMode.off,
        dns: everything,
        ipv6: true,
      );
      expect(result.configJson, same(text));
      expect(result.hijacksDns, isFalse);
    });
  });

  group('then GeoConfigGate', () {
    final geoGate = GeoConfigGate(Talker());

    test('the fakedns server survives with no geo data installed', () {
      final afterPolicy = applyTo(
        scaffold(),
        dns: const DnsSettings(fakeDns: true, direct: DirectDns.system),
      ).configJson;
      final config =
          jsonDecode(geoGate.prepare(afterPolicy, const GeoState.absent()))
              as Map<String, dynamic>;
      final servers = serversOf(config);
      expect(servers.first, 'fakedns');
      // dns-ru keeps its .ru scope, loses only expectIPs (geoip needs data).
      final ru = server(config, 'dns-ru');
      expect(ru['address'], 'localhost');
      expect(ru['domains'], ['domain:ru', 'domain:xn--p1ai']);
      expect(ru.containsKey('expectIPs'), isFalse);
    });
  });
}
