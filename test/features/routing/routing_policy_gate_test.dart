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
  }) => gate.apply(jsonEncode(config), split: split, adBlock: adBlock);

  Map<String, dynamic> decode(String s) =>
      jsonDecode(s) as Map<String, dynamic>;

  List<Map<String, dynamic>> rulesOf(Map<String, dynamic> config) =>
      (config['routing']['rules'] as List).cast<Map<String, dynamic>>();

  // XrayConfigBuilder._wrap() output: proxy + direct + block outbound and a
  // single bittorrent->direct rule, no destination matchers.
  Map<String, dynamic> scaffold() => {
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

  test('both toggles off — config returned byte-identical', () {
    final src = jsonEncode(scaffold());
    expect(
      gate.apply(src, split: RuBypassMode.off, adBlock: AdBlockMode.off),
      same(src),
    );
  });

  test('scaffold + bypassRu — RU-bypass prepended, order preserved', () {
    final result = decode(run(scaffold()));
    final rules = rulesOf(result);

    expect(rules.map((r) => r['ruleTag']).take(3), [
      'ru-bypass-bittorrent',
      'ru-bypass-ip',
      'ru-bypass-domain',
    ]);
    expect(rules.last['protocol'], ['bittorrent']); // original rule kept, last
    expect(rules[1]['ip'], ['geoip:private', 'geoip:ru']);
    expect(
      rules[2]['domain'],
      containsAll(<String>[
        'domain:ru',
        'domain:xn--p1ai',
        'geosite:category-ru',
        'geosite:category-gov-ru',
      ]),
    );
  });

  test('blockAds — ad-block rule first, block outbound ensured', () {
    final result = decode(run(scaffold(), adBlock: AdBlockMode.full));
    final rules = rulesOf(result);

    expect(rules.first['ruleTag'], 'ad-block');
    expect(rules.first['domain'], ['geosite:category-ads-all']);
    expect(rules.first['outboundTag'], 'block');
    // ad-block sits above the RU-bypass rules
    expect(rules[1]['ruleTag'], 'ru-bypass-bittorrent');
    expect(
      (result['outbounds'] as List).any((o) => o['tag'] == 'block'),
      isTrue,
    );
  });

  test('adBlock basic injects category-ads, not category-ads-all', () {
    final result = decode(run(scaffold(), adBlock: AdBlockMode.basic));
    final rules = rulesOf(result);

    expect(rules.first['ruleTag'], 'ad-block');
    expect(rules.first['domain'], ['geosite:category-ads']);
  });

  test('blockAds only (split off) — just the one rule', () {
    final result = decode(
      run(scaffold(), split: RuBypassMode.off, adBlock: AdBlockMode.full),
    );
    final tags = rulesOf(result).map((r) => r['ruleTag']).toList();
    expect(tags, ['ad-block', null]); // ad-block + original bittorrent rule
  });

  test('blockAds ensures a block outbound when the config lacks one', () {
    final result = decode(
      run(
        {
          'outbounds': [
            {'tag': 'proxy'},
            {'tag': 'direct'},
          ],
        },
        split: RuBypassMode.off,
        adBlock: AdBlockMode.full,
      ),
    );
    final block = (result['outbounds'] as List).firstWhere(
      (o) => o['tag'] == 'block',
    );
    expect(block['protocol'], 'blackhole');
  });

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
    expect(
      gate.apply(src, split: RuBypassMode.bypassRu, adBlock: AdBlockMode.full),
      same(src),
    );
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
    expect(rulesOf(result), hasLength(3));
  });

  test('routing with empty rules list — treated as no policy, injected', () {
    final result = decode(
      run({
        'outbounds': [
          {'tag': 'proxy'},
          {'tag': 'direct'},
        ],
        'routing': {'rules': <dynamic>[]},
      }),
    );
    expect(rulesOf(result), hasLength(3));
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
      expect(
        gate.apply(src, split: RuBypassMode.bypassRu, adBlock: AdBlockMode.off),
        same(src),
      );
    },
  );

  group('RoutingPolicyGate -> GeoConfigGate', () {
    final geoGate = GeoConfigGate(Talker());

    test('geo absent — geo tokens stripped, .ru/.рф suffix survives', () {
      final afterSplit = run(scaffold());
      final afterGeo = geoGate.prepare(afterSplit, const GeoState.absent());
      final config = decode(afterGeo);
      final encoded = jsonEncode(config);

      expect(encoded, isNot(contains('geosite:')));
      expect(encoded, isNot(contains('geoip:')));
      expect(encoded, contains('domain:ru'));
      expect(encoded, contains('domain:xn--p1ai'));
      final domainRule = rulesOf(
        config,
      ).firstWhere((r) => r['ruleTag'] == 'ru-bypass-domain');
      expect(domainRule['domain'], ['domain:ru', 'domain:xn--p1ai']);
    });

    test(
      'geo absent + blockAds — ad-block rule is dropped (nothing to match)',
      () {
        final afterSplit = run(scaffold(), adBlock: AdBlockMode.full);
        final afterGeo = geoGate.prepare(afterSplit, const GeoState.absent());
        final config = decode(afterGeo);

        expect(jsonEncode(config), isNot(contains('category-ads-all')));
        expect(rulesOf(config).any((r) => r['ruleTag'] == 'ad-block'), isFalse);
      },
    );

    test('geo ready — geosite:category-ru and category-ads-all survive', () {
      final afterSplit = run(scaffold(), adBlock: AdBlockMode.full);
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
      final afterGeo = geoGate.prepare(afterSplit, ready);

      expect(afterGeo, contains('geosite:category-ru'));
      expect(afterGeo, contains('geoip:ru'));
      expect(afterGeo, contains('geosite:category-ads-all'));
    });
  });
}
