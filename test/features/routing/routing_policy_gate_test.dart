import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/geo/cubit/geo_cubit.dart';
import 'package:slipstream/features/geo/data/geo_catalog.dart';
import 'package:slipstream/features/geo/data/geo_config_gate.dart';
import 'package:slipstream/features/routing/data/ad_block_mode.dart';
import 'package:slipstream/features/routing/data/routing_policy_gate.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';

void main() {
  final gate = RoutingPolicyGate(Talker());

  String run(
    Map<String, dynamic> config, {
    RuBypassMode split = RuBypassMode.bypassRu,
    AdBlockMode adBlock = AdBlockMode.off,
  }) =>
      gate.apply(jsonEncode(config), split: split, adBlock: adBlock).configJson;

  /// For the "left untouched" cases: same string back, DNS not hijacked.
  void expectUntouched(String src, PolicyResult result) {
    expect(result.configJson, same(src));
    expect(result.hijacksDns, isFalse);
  }

  Map<String, dynamic> decode(String s) =>
      jsonDecode(s) as Map<String, dynamic>;

  List<Map<String, dynamic>> rulesOf(Map<String, dynamic> config) =>
      (config['routing']['rules'] as List).cast<Map<String, dynamic>>();

  List<Object?> tagsOf(Map<String, dynamic> config) =>
      rulesOf(config).map((r) => r['ruleTag']).toList();

  Map<String, dynamic> rule(Map<String, dynamic> config, String tag) =>
      rulesOf(config).firstWhere((r) => r['ruleTag'] == tag);

  Map<String, dynamic>? outbound(Map<String, dynamic> config, String tag) =>
      (config['outbounds'] as List).cast<Map<String, dynamic>?>().firstWhere(
        (o) => o!['tag'] == tag,
        orElse: () => null,
      );

  // XrayConfigBuilder._wrap() output: proxy + direct + block outbound, a
  // placeholder dns block and a single bittorrent->direct rule, no
  // destination matchers.
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
      'domainStrategy': 'IPIfNonMatch',
      'rules': [
        {
          'type': 'field',
          'protocol': ['bittorrent'],
          'outboundTag': 'direct',
        },
      ],
    },
  };

  test('bypassRu — full rule order, original rules kept last', () {
    final result = decode(run(scaffold()));
    expect(tagsOf(result), [
      'dns-ru',
      'dns-remote',
      'dns-hijack',
      'block-quic',
      'bittorrent-direct',
      'block-public-dns',
      'block-doh',
      'ru-bypass-domain',
      'private-direct',
      'ru-bypass-ip',
      null, // the scaffold's own bittorrent rule
    ]);
  });

  test('both toggles off — DNS protection still installed, no RU parts', () {
    final result = decode(
      run(scaffold(), split: RuBypassMode.off, adBlock: AdBlockMode.off),
    );
    expect(tagsOf(result), [
      'dns-remote',
      'dns-hijack',
      'block-quic',
      'bittorrent-direct',
      'block-public-dns',
      'block-doh',
      'private-direct',
      null,
    ]);
    final servers = result['dns']['servers'] as List;
    expect(servers.map((s) => s['tag']), ['dns-remote']);
  });

  test('dns block replaced: Yandex for RU names, remote DoH for the rest', () {
    final result = decode(run(scaffold()));
    final servers = (result['dns']['servers'] as List)
        .cast<Map<String, dynamic>>();

    expect(servers.map((s) => s['tag']), ['dns-ru', 'dns-remote']);
    final ru = servers.first;
    expect(ru['address'], 'https://77.88.8.8/dns-query');
    expect(ru['domains'], contains('domain:ru'));
    expect(ru['expectIPs'], ['geoip:ru']);
    expect(ru['skipFallback'], isTrue);
    expect(servers.last['address'], 'https://8.8.8.8/dns-query');
  });

  test('resolver queries are routed before anything that would block them', () {
    final tags = tagsOf(decode(run(scaffold())));
    // dns-remote talks to 8.8.8.8:443, which block-public-dns would catch.
    expect(
      tags.indexOf('dns-remote'),
      lessThan(tags.indexOf('block-public-dns')),
    );
    // The port-53 hijack must win over geoip:private (system DNS may sit on a
    // private address).
    expect(
      tags.indexOf('dns-hijack'),
      lessThan(tags.indexOf('private-direct')),
    );
  });

  test('rules point at the right outbounds and inbound', () {
    final result = decode(run(scaffold()));
    expect(rule(result, 'dns-ru')['outboundTag'], 'direct');
    expect(rule(result, 'dns-remote')['outboundTag'], 'proxy');
    final hijack = rule(result, 'dns-hijack');
    expect(hijack['inboundTag'], ['socks']);
    expect(hijack['port'], '53');
    expect(hijack['outboundTag'], 'dns-out');
  });

  test('DoT (853) is never blocked — strict Private DNS keeps working', () {
    final result = decode(run(scaffold()));
    expect(rule(result, 'block-public-dns')['port'], '53,443');
    expect(rule(result, 'block-doh')['port'], '443');
  });

  test('dns-out drops AAAA and HTTPS records via rules, not blockTypes', () {
    final dnsOut = outbound(decode(run(scaffold())), 'dns-out')!;
    expect(dnsOut['protocol'], 'dns');
    expect(dnsOut['settings']['rules'], [
      {'action': 'return', 'qType': '28,65'},
    ]);
    expect(dnsOut['settings'], isNot(contains('blockTypes')));
  });

  test('adBlock full — after the DNS blocks, before the direct rules', () {
    final result = decode(run(scaffold(), adBlock: AdBlockMode.full));
    final tags = tagsOf(result);
    final ad = rule(result, 'ad-block');

    expect(ad['domain'], ['geosite:category-ads-all']);
    expect(ad['outboundTag'], 'block');
    expect(tags.indexOf('ad-block'), tags.indexOf('block-doh') + 1);
    expect(
      tags.indexOf('ad-block'),
      lessThan(tags.indexOf('ru-bypass-domain')),
    );
  });

  test('adBlock basic injects category-ads, not category-ads-all', () {
    final result = decode(run(scaffold(), adBlock: AdBlockMode.basic));
    expect(rule(result, 'ad-block')['domain'], ['geosite:category-ads']);
  });

  test('missing direct / block / dns-out outbounds are added', () {
    final result = decode(
      run({
        'outbounds': [
          {'tag': 'proxy'},
        ],
      }),
    );
    expect(outbound(result, 'direct')!['protocol'], 'freedom');
    expect(outbound(result, 'block')!['protocol'], 'blackhole');
    expect(outbound(result, 'dns-out')!['protocol'], 'dns');
    expect((result['outbounds'] as List).first['tag'], 'proxy');
  });

  test('untagged first outbound gets tagged proxy and DNS goes through it', () {
    final result = decode(
      run({
        'outbounds': [
          {'protocol': 'vless'},
        ],
      }),
    );
    expect((result['outbounds'] as List).first['tag'], 'proxy');
    expect(rule(result, 'dns-remote')['outboundTag'], 'proxy');
  });

  test('a custom first-outbound tag is used as the proxy tag', () {
    final result = decode(
      run({
        'outbounds': [
          {'tag': 'my-server', 'protocol': 'vless'},
        ],
      }),
    );
    expect(rule(result, 'dns-remote')['outboundTag'], 'my-server');
  });

  test('no outbounds — returned unchanged', () {
    final src = jsonEncode({'outbounds': <dynamic>[]});
    expectUntouched(
      src,
      gate.apply(src, split: RuBypassMode.bypassRu, adBlock: AdBlockMode.off),
    );
  });

  test('own policy injected — reports that the config hijacks DNS', () {
    for (final split in RuBypassMode.values) {
      final result = gate.apply(
        jsonEncode(scaffold()),
        split: split,
        adBlock: AdBlockMode.off,
      );
      expect(result.hijacksDns, isTrue, reason: 'split=$split');
    }
  });

  test(
    'strict Private DNS — own configs still hijack (no hosts blackholes)',
    () {
      final result = gate.apply(
        jsonEncode(scaffold()),
        split: RuBypassMode.bypassRu,
        adBlock: AdBlockMode.off,
        privateDnsStrict: true,
      );
      expect(result.hijacksDns, isTrue);
      expect(tagsOf(decode(result.configJson)), contains('dns-hijack'));
    },
  );

  test('provider config with its own domain rule — untouched', () {
    final provider = {
      'outbounds': [
        {'tag': 'proxy'},
        {'tag': 'direct'},
      ],
      'routing': {
        'rules': [
          {
            'ruleTag': 'direct-big-list',
            'domain': ['geosite:category-ru', 'vk.com'],
            'outboundTag': 'direct',
          },
        ],
      },
    };
    final src = jsonEncode(provider);
    expectUntouched(
      src,
      gate.apply(src, split: RuBypassMode.bypassRu, adBlock: AdBlockMode.full),
    );
  });

  group('provider config with its own resolvers', () {
    Map<String, dynamic> provider({
      Object? dns = const {
        'servers': [
          {
            'address': 'https://77.88.8.8/dns-query',
            'domains': ['domain:ru'],
          },
          'https://1.1.1.1/dns-query',
        ],
      },
      List<Map<String, dynamic>> extraOutbounds = const [],
    }) => {
      'dns': ?dns,
      'outbounds': [
        {'tag': 'proxy', 'protocol': 'vless'},
        {'tag': 'direct', 'protocol': 'freedom'},
        ...extraOutbounds,
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

    test('port-53 hijack prepended, everything else kept', () {
      final src = provider();
      final result = gate.apply(
        jsonEncode(src),
        split: RuBypassMode.bypassRu,
        adBlock: AdBlockMode.full,
      );
      final config = decode(result.configJson);
      final rules = rulesOf(config);

      expect(result.hijacksDns, isTrue);
      expect(rules.first['ruleTag'], 'dns-hijack');
      expect(rules.first['inboundTag'], ['socks']);
      expect(rules.first['port'], '53');
      expect(rules.first['outboundTag'], 'dns-out');
      // The provider's own rules follow untouched, and nothing of ours
      // (bypass, ad-block, dns block) is added.
      expect(rules.skip(1).toList(), src['routing']['rules']);
      expect(config['dns'], src['dns']);
      expect(outbound(config, 'dns-out')!['protocol'], 'dns');
      expect(outbound(config, 'dns-out')!.containsKey('settings'), isFalse);
    });

    test('strict Private DNS — provider DNS left alone', () {
      // Its dns.hosts may blackhole dns.google; hijacking would answer the
      // OS's DoT bootstrap lookup with 0.0.0.0.
      final src = jsonEncode(provider());
      expectUntouched(
        src,
        gate.apply(
          src,
          split: RuBypassMode.bypassRu,
          adBlock: AdBlockMode.off,
          privateDnsStrict: true,
        ),
      );
    });

    test('an existing dns outbound is reused, not duplicated', () {
      final config = decode(
        run(
          provider(
            extraOutbounds: [
              {'tag': 'their-dns', 'protocol': 'dns'},
            ],
          ),
        ),
      );
      expect(rulesOf(config).first['outboundTag'], 'their-dns');
      final dnsOutbounds = (config['outbounds'] as List).where(
        (o) => o['protocol'] == 'dns',
      );
      expect(dnsOutbounds, hasLength(1));
    });

    test(
      'no dns block — untouched (xray would resolve outside the tunnel)',
      () {
        final src = jsonEncode(provider(dns: null));
        expectUntouched(
          src,
          gate.apply(
            src,
            split: RuBypassMode.bypassRu,
            adBlock: AdBlockMode.off,
          ),
        );
      },
    );

    test('only local resolvers — untouched', () {
      for (final servers in [
        ['localhost'],
        ['https+local://1.1.1.1/dns-query'],
        [
          {'address': 'tcp+local://8.8.8.8'},
        ],
      ]) {
        final src = jsonEncode(provider(dns: {'servers': servers}));
        expectUntouched(
          src,
          gate.apply(
            src,
            split: RuBypassMode.bypassRu,
            adBlock: AdBlockMode.off,
          ),
        );
      }
    });
  });

  test('JSON with no routing block — routing created, rules injected', () {
    final result = decode(
      run({
        'outbounds': [
          {'tag': 'proxy'},
          {'tag': 'direct'},
        ],
      }),
    );
    expect(result['routing']['domainStrategy'], 'IPIfNonMatch');
    expect(tagsOf(result), hasLength(10));
  });

  test(
    'heuristic — a single geoip:private direct rule counts as own routing',
    () {
      final src = jsonEncode({
        'outbounds': [
          {'tag': 'proxy'},
          {'tag': 'direct'},
        ],
        'routing': {
          'rules': [
            {
              'ip': ['geoip:private'],
              'outboundTag': 'direct',
            },
          ],
        },
      });
      expectUntouched(
        src,
        gate.apply(src, split: RuBypassMode.bypassRu, adBlock: AdBlockMode.off),
      );
    },
  );

  group('RoutingPolicyGate -> GeoConfigGate', () {
    final geoGate = GeoConfigGate(Talker());

    test('geo absent — geo tokens stripped, .ru/.рф suffix survives', () {
      final afterPolicy = run(scaffold());
      final config = decode(
        geoGate.prepare(afterPolicy, const GeoState.absent()),
      );
      final encoded = jsonEncode(config);

      expect(encoded, isNot(contains('geosite:')));
      expect(encoded, isNot(contains('geoip:')));
      expect(rule(config, 'ru-bypass-domain')['domain'], [
        'domain:ru',
        'domain:xn--p1ai',
      ]);
      // Rules left with nothing to match are dropped; plain-IP ones stay.
      final tags = tagsOf(config);
      expect(tags, isNot(contains('private-direct')));
      expect(tags, isNot(contains('ru-bypass-ip')));
      expect(tags, contains('block-public-dns'));
      // The Yandex resolver keeps its .ru/.рф scope, loses only expectIPs.
      final ru = (config['dns']['servers'] as List).first as Map;
      expect(ru['tag'], 'dns-ru');
      expect(ru['domains'], ['domain:ru', 'domain:xn--p1ai']);
      expect(ru.containsKey('expectIPs'), isFalse);
    });

    test(
      'geo absent + blockAds — ad-block rule is dropped (nothing to match)',
      () {
        final afterPolicy = run(scaffold(), adBlock: AdBlockMode.full);
        final config = decode(
          geoGate.prepare(afterPolicy, const GeoState.absent()),
        );
        expect(jsonEncode(config), isNot(contains('category-ads-all')));
        expect(tagsOf(config), isNot(contains('ad-block')));
      },
    );

    test('geo ready — geosite:category-ru and category-ads-all survive', () {
      final afterPolicy = run(scaffold(), adBlock: AdBlockMode.full);
      final ready = GeoState.ready(
        catalog: GeoCatalog(
          site: const {
            'geosite:category-ru',
            'geosite:category-gov-ru',
            'geosite:private',
            'geosite:category-ads-all',
          },
          ip: const {'geoip:ru', 'geoip:private'},
        ),
        tag: 't',
        updatedAt: DateTime(2026),
      );
      final afterGeo = geoGate.prepare(afterPolicy, ready);

      expect(afterGeo, contains('geosite:category-ru'));
      expect(afterGeo, contains('geoip:ru'));
      expect(afterGeo, contains('geosite:category-ads-all'));
    });
  });
}
