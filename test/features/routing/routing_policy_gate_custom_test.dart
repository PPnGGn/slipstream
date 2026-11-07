import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/geo/cubit/geo_cubit.dart';
import 'package:slipstream/features/geo/data/geo_config_gate.dart';
import 'package:slipstream/features/routing/data/ad_block_mode.dart';
import 'package:slipstream/features/routing/data/custom_rule.dart';
import 'package:slipstream/features/routing/data/routing_policy_gate.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';
import 'package:talker_flutter/talker_flutter.dart';

void main() {
  final gate = RoutingPolicyGate(Talker());

  CustomRule r(String value, [RuleAction action = RuleAction.proxy]) =>
      CustomRule(id: value, value: value, action: action);

  String run(
    Map<String, dynamic> config, {
    List<CustomRule> custom = const [],
    RuBypassMode split = RuBypassMode.bypassRu,
    AdBlockMode adBlock = AdBlockMode.off,
    bool lanBypass = true,
  }) => gate
      .apply(
        jsonEncode(config),
        split: split,
        adBlock: adBlock,
        lanBypass: lanBypass,
        customRules: custom,
      )
      .configJson;

  Map<String, dynamic> decode(String s) =>
      jsonDecode(s) as Map<String, dynamic>;

  List<Map<String, dynamic>> rulesOf(Map<String, dynamic> config) =>
      (config['routing']['rules'] as List).cast<Map<String, dynamic>>();

  List<Object?> tagsOf(Map<String, dynamic> config) =>
      rulesOf(config).map((e) => e['ruleTag']).toList();

  Map<String, dynamic> rule(Map<String, dynamic> config, String tag) =>
      rulesOf(config).firstWhere((e) => e['ruleTag'] == tag);

  Map<String, dynamic> scaffold({String proxyTag = 'proxy'}) => {
    'dns': {
      'servers': ['https://8.8.8.8/dns-query'],
    },
    'outbounds': [
      {'tag': proxyTag, 'protocol': 'vless'},
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

  Map<String, dynamic> providerConfig() => {
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

  test('no custom rules — the config is what it was before the feature', () {
    final without = decode(run(scaffold()));
    final withEmpty = decode(run(scaffold(), custom: const []));
    expect(tagsOf(withEmpty), tagsOf(without));
    expect(
      tagsOf(
        withEmpty,
      ).whereType<String>().where((t) => t.startsWith('custom:')),
      isEmpty,
    );
  });

  group('shape of a rule', () {
    test('a domain matches with its subdomains', () {
      final result = decode(run(scaffold(), custom: [r('grani.ru')]));
      final custom = rule(result, 'custom:grani.ru');
      expect(custom['type'], 'field');
      expect(custom['domain'], ['domain:grani.ru']);
      expect(custom.containsKey('ip'), isFalse);
    });

    test('an address or range goes into ip as it is', () {
      final result = decode(
        run(
          scaffold(),
          custom: [r('10.1.0.0/16'), r('1.2.3.4'), r('2001:db8::/32')],
        ),
      );
      expect(rule(result, 'custom:10.1.0.0/16')['ip'], ['10.1.0.0/16']);
      expect(rule(result, 'custom:1.2.3.4')['ip'], ['1.2.3.4']);
      expect(rule(result, 'custom:2001:db8::/32')['ip'], ['2001:db8::/32']);
      expect(rule(result, 'custom:1.2.3.4').containsKey('domain'), isFalse);
    });

    test('the action picks the outbound', () {
      final result = decode(
        run(
          scaffold(),
          custom: [
            r('a.com', RuleAction.proxy),
            r('b.com', RuleAction.direct),
            r('c.com', RuleAction.block),
          ],
        ),
      );
      expect(rule(result, 'custom:a.com')['outboundTag'], 'proxy');
      expect(rule(result, 'custom:b.com')['outboundTag'], 'direct');
      expect(rule(result, 'custom:c.com')['outboundTag'], 'block');
    });

    test("proxy means the config's own first outbound, whatever its tag", () {
      final result = decode(
        run(scaffold(proxyTag: 'my-vless'), custom: [r('a.com')]),
      );
      expect(rule(result, 'custom:a.com')['outboundTag'], 'my-vless');
    });

    test(
      'an untagged first outbound gets the proxy tag the rule points at',
      () {
        final config = {
          'outbounds': [
            {'protocol': 'vless'},
          ],
        };
        final result = decode(run(config, custom: [r('a.com')]));
        final proxy = (result['outbounds'] as List).first as Map;
        expect(proxy['tag'], 'proxy');
        expect(rule(result, 'custom:a.com')['outboundTag'], 'proxy');
      },
    );

    test('direct and block outbounds exist even if the config had none', () {
      final config = {
        'outbounds': [
          {'tag': 'proxy', 'protocol': 'vless'},
        ],
      };
      final result = decode(
        run(
          config,
          custom: [r('a.com', RuleAction.direct), r('b.com', RuleAction.block)],
        ),
      );
      final tags = (result['outbounds'] as List).map((o) => (o as Map)['tag']);
      expect(tags, containsAll(['direct', 'block']));
    });
  });

  group('place in the rule list', () {
    test('after the DNS and leak protection, before every general list', () {
      final result = decode(
        run(scaffold(), custom: [r('grani.ru')], adBlock: AdBlockMode.full),
      );
      final tags = tagsOf(result);
      final at = tags.indexOf('custom:grani.ru');
      for (final protection in [
        'dns-ru',
        'dns-remote',
        'dns-hijack',
        'block-quic',
        'bittorrent-direct',
        'block-public-dns',
        'block-doh',
      ]) {
        expect(at, greaterThan(tags.indexOf(protection)), reason: protection);
      }
      for (final general in [
        'ad-block',
        'ru-bypass-domain',
        'private-direct-domain',
        'private-direct',
        'ru-bypass-ip',
      ]) {
        expect(at, lessThan(tags.indexOf(general)), reason: general);
      }
    });

    test('grani.ru → proxy beats the .ru bypass', () {
      final result = decode(run(scaffold(), custom: [r('grani.ru')]));
      final tags = tagsOf(result);
      expect(
        tags.indexOf('custom:grani.ru'),
        lessThan(tags.indexOf('ru-bypass-domain')),
      );
    });

    test('a range of the user beats the LAN bypass', () {
      final result = decode(run(scaffold(), custom: [r('192.168.1.0/24')]));
      final tags = tagsOf(result);
      expect(
        tags.indexOf('custom:192.168.1.0/24'),
        lessThan(tags.indexOf('private-direct')),
      );
    });

    test('a rule for a public resolver cannot reopen the DNS leak', () {
      final result = decode(
        run(scaffold(), custom: [r('8.8.8.8', RuleAction.direct)]),
      );
      final tags = tagsOf(result);
      expect(
        tags.indexOf('custom:8.8.8.8'),
        greaterThan(tags.indexOf('block-public-dns')),
      );
    });

    test('the config\'s own rules stay last', () {
      final result = decode(run(scaffold(), custom: [r('a.com')]));
      expect(tagsOf(result).last, isNull); // the scaffold's bittorrent rule
    });

    test('present with every switch off', () {
      final result = decode(
        run(
          scaffold(),
          custom: [r('a.com')],
          split: RuBypassMode.off,
          lanBypass: false,
        ),
      );
      expect(tagsOf(result), contains('custom:a.com'));
    });
  });

  group('order among the rules of the user', () {
    List<Object?> customTags(Map<String, dynamic> config) => tagsOf(
      config,
    ).whereType<String>().where((t) => t.startsWith('custom:')).toList();

    test('the most specific goes first, however they were added', () {
      final result = decode(
        run(
          scaffold(),
          custom: [
            r('google.com', RuleAction.direct),
            r('mail.google.com', RuleAction.proxy),
          ],
        ),
      );
      expect(customTags(result), [
        'custom:mail.google.com',
        'custom:google.com',
      ]);
    });

    test('domains before addresses, longer prefix first', () {
      final result = decode(
        run(
          scaffold(),
          custom: [r('10.0.0.0/8'), r('example.com'), r('10.1.2.0/24')],
        ),
      );
      expect(customTags(result), [
        'custom:example.com',
        'custom:10.1.2.0/24',
        'custom:10.0.0.0/8',
      ]);
    });
  });

  group('configs with a routing of their own', () {
    PolicyResult applyTo(
      Map<String, dynamic> config, {
      List<CustomRule> custom = const [],
      bool privateDnsStrict = false,
      AdBlockMode adBlock = AdBlockMode.full,
    }) => gate.apply(
      jsonEncode(config),
      split: RuBypassMode.bypassRu,
      adBlock: adBlock,
      customRules: custom,
      privateDnsStrict: privateDnsStrict,
    );

    // A panel's config as the user's own server sends it: routed resolver,
    // its own domain / ip rules, tags `proxy` / `direct` / `block`.
    Map<String, dynamic> panelConfig() => {
      'dns': {
        'servers': ['https://1.1.1.1/dns-query'],
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
            'domain': ['geosite:category-ads-all'],
            'outboundTag': 'block',
          },
          {
            'type': 'field',
            'ip': ['geoip:ru'],
            'outboundTag': 'direct',
          },
          {'type': 'field', 'network': 'tcp,udp', 'outboundTag': 'proxy'},
        ],
      },
    };

    test('no custom rules — left untouched, as before', () {
      final src = jsonEncode(providerConfig());
      final result = gate.apply(
        src,
        split: RuBypassMode.bypassRu,
        adBlock: AdBlockMode.off,
      );
      expect(result.configJson, same(src));
      expect(result.hijacksDns, isFalse);
    });

    test(
      'custom rules go right after the DNS hijack, before the panel\'s own',
      () {
        final result = applyTo(
          panelConfig(),
          custom: [
            r('youtube.com', RuleAction.direct),
            r('ya.ru', RuleAction.block),
          ],
        );
        final config = decode(result.configJson);
        final tags = tagsOf(config);
        expect(tags.take(3), [
          'dns-hijack',
          'custom:youtube.com',
          'custom:ya.ru',
        ]);
        // The panel's three rules follow, as they were.
        expect(tags.skip(3), [null, null, null]);
        expect(rulesOf(config)[3]['domain'], ['geosite:category-ads-all']);
        expect(rulesOf(config).last['network'], 'tcp,udp');
        expect(result.hijacksDns, isTrue);
      },
    );

    test('the actions point at the panel\'s outbounds', () {
      final config = decode(
        applyTo(
          panelConfig(),
          custom: [
            r('a.com', RuleAction.proxy),
            r('b.com', RuleAction.direct),
            r('c.com', RuleAction.block),
          ],
        ).configJson,
      );
      expect(rule(config, 'custom:a.com')['outboundTag'], 'proxy');
      expect(rule(config, 'custom:b.com')['outboundTag'], 'direct');
      expect(rule(config, 'custom:c.com')['outboundTag'], 'block');
    });

    test('proxy is the first outbound, whatever its tag', () {
      final panel = panelConfig();
      ((panel['outbounds'] as List).first as Map)['tag'] = 'my-vless';
      final config = decode(applyTo(panel, custom: [r('a.com')]).configJson);
      expect(rule(config, 'custom:a.com')['outboundTag'], 'my-vless');
    });

    test(
      'no duplicate outbounds when the panel already has direct and block',
      () {
        final config = decode(
          applyTo(
            panelConfig(),
            custom: [
              r('a.com', RuleAction.direct),
              r('b.com', RuleAction.block),
            ],
          ).configJson,
        );
        final tags = (config['outbounds'] as List).map(
          (o) => (o as Map)['tag'],
        );
        expect(tags.where((t) => t == 'direct'), hasLength(1));
        expect(tags.where((t) => t == 'block'), hasLength(1));
      },
    );

    test('missing direct and block outbounds are added', () {
      final panel = panelConfig();
      panel['outbounds'] = [
        {'tag': 'proxy', 'protocol': 'vless'},
      ];
      final config = decode(
        applyTo(
          panel,
          custom: [r('a.com', RuleAction.direct), r('b.com', RuleAction.block)],
        ).configJson,
      );
      final tags = (config['outbounds'] as List).map((o) => (o as Map)['tag']);
      expect(tags, containsAll(['proxy', 'direct', 'block']));
      expect((config['outbounds'] as List).first['tag'], 'proxy');
    });

    test('most specific first among them', () {
      final config = decode(
        applyTo(
          panelConfig(),
          custom: [
            r('google.com', RuleAction.direct),
            r('mail.google.com', RuleAction.proxy),
          ],
        ).configJson,
      );
      expect(tagsOf(config).skip(1).take(2), [
        'custom:mail.google.com',
        'custom:google.com',
      ]);
    });

    test('no DNS hijack for this config — custom rules stand first', () {
      // providerConfig() has no dns block: the hijack is not installed.
      final result = applyTo(providerConfig(), custom: [r('grani.ru')]);
      final config = decode(result.configJson);
      expect(tagsOf(config), ['custom:grani.ru', null]);
      expect(result.hijacksDns, isFalse);
    });

    test('strict Private DNS — no hijack, custom rules still added', () {
      final result = applyTo(
        panelConfig(),
        custom: [r('grani.ru')],
        privateDnsStrict: true,
      );
      final config = decode(result.configJson);
      expect(tagsOf(config).first, 'custom:grani.ru');
      expect(tagsOf(config), isNot(contains('dns-hijack')));
      expect(result.hijacksDns, isFalse);
    });

    test('the switches still do not act on it', () {
      final config = decode(
        applyTo(panelConfig(), custom: [r('a.com')]).configJson,
      );
      final tags = tagsOf(config).whereType<String>();
      for (final ours in [
        'ad-block',
        'ru-bypass-domain',
        'ru-bypass-ip',
        'private-direct',
        'private-direct-domain',
        'block-quic',
      ]) {
        expect(tags, isNot(contains(ours)), reason: ours);
      }
      // And its dns block is its own.
      expect(config['dns']['servers'], ['https://1.1.1.1/dns-query']);
    });

    test('a config with rules but no outbounds is left alone', () {
      final panel = panelConfig()..['outbounds'] = <dynamic>[];
      final src = jsonEncode(panel);
      final result = gate.apply(
        src,
        split: RuBypassMode.bypassRu,
        adBlock: AdBlockMode.off,
        customRules: [r('a.com')],
        privateDnsStrict: true,
      );
      expect(result.configJson, same(src));
    });

    test('survives the geo gate: plain rules stay with no geo data', () {
      final geoGate = GeoConfigGate(Talker());
      final after = applyTo(
        panelConfig(),
        custom: [r('youtube.com', RuleAction.direct)],
      );
      final config = decode(
        geoGate.prepare(after.configJson, const GeoState.absent()),
      );
      expect(rule(config, 'custom:youtube.com')['domain'], [
        'domain:youtube.com',
      ]);
    });

    test('ownsRouting: a scaffold has none, a provider config has', () {
      expect(RoutingPolicyGate.ownsRouting(jsonEncode(scaffold())), isFalse);
      expect(
        RoutingPolicyGate.ownsRouting(jsonEncode(providerConfig())),
        isTrue,
      );
    });

    test('ownsRouting: an ip rule counts too', () {
      final config = {
        'outbounds': [
          {'tag': 'p'},
        ],
        'routing': {
          'rules': [
            {
              'ip': ['geoip:cn'],
              'outboundTag': 'direct',
            },
          ],
        },
      };
      expect(RoutingPolicyGate.ownsRouting(jsonEncode(config)), isTrue);
    });

    test('ownsRouting: no routing at all, no rules, broken JSON', () {
      expect(
        RoutingPolicyGate.ownsRouting(jsonEncode({'outbounds': []})),
        isFalse,
      );
      expect(
        RoutingPolicyGate.ownsRouting(
          jsonEncode({
            'routing': {'rules': []},
          }),
        ),
        isFalse,
      );
      expect(RoutingPolicyGate.ownsRouting('{broken'), isFalse);
      expect(RoutingPolicyGate.ownsRouting('[1, 2]'), isFalse);
    });
  });

  test(
    'RoutingPolicyGate -> GeoConfigGate: plain rules survive without geo data',
    () {
      final geoGate = GeoConfigGate(Talker());
      final afterPolicy = run(
        scaffold(),
        custom: [r('grani.ru'), r('10.1.0.0/16', RuleAction.block)],
      );
      final config = decode(
        geoGate.prepare(afterPolicy, const GeoState.absent()),
      );
      expect(rule(config, 'custom:grani.ru')['domain'], ['domain:grani.ru']);
      expect(rule(config, 'custom:10.1.0.0/16')['ip'], ['10.1.0.0/16']);
    },
  );
}
