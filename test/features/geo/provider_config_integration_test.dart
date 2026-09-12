import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/geo/cubit/geo_cubit.dart';
import 'package:slipstream/features/geo/data/geo_catalog.dart';
import 'package:slipstream/features/geo/data/geo_config_gate.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/custom_json_parser.dart';

/// End-to-end on a real Remnawave provider config (fixtures/provider_config.json,
/// captured from the panel): parse -> gate. The panel's split-tunnel references
/// geosite:category-ru / vk / yandex / youtube / category-gov-ru and geoip:ru.
void main() {
  final raw = File(
    'test/features/geo/fixtures/provider_config.json',
  ).readAsStringSync();
  final parser = CustomJsonParser(Talker());
  final gate = GeoConfigGate(Talker());

  late String parsedConfig;

  setUp(() {
    final servers = parser.parse(raw, 'sub');
    expect(servers, hasLength(1));
    parsedConfig = servers.single.configJson;
  });

  test('parser keeps every geo reference verbatim', () {
    expect(parsedConfig, contains('geosite:category-ru'));
    expect(parsedConfig, contains('geoip:ru'));
    // dns block survived untouched
    final dns = jsonDecode(parsedConfig)['dns'] as Map<String, dynamic>;
    expect(jsonEncode(dns), contains('geosite:category-ru'));
  });

  test('gate with no geo installed strips every geo ref, output still valid', () {
    final gated = gate.prepare(parsedConfig, const GeoState.absent());
    final config = jsonDecode(gated) as Map<String, dynamic>; // parses

    expect(gated, isNot(contains('geosite:')));
    expect(gated, isNot(contains('geoip:')));

    // proxy outbound + a routing section still there
    final outbounds = (config['outbounds'] as List).cast<Map>();
    expect(outbounds.first['tag'], 'proxy');
    expect(config['routing'], isNotNull);

    // no routing rule left with only meta keys
    for (final rule in (config['routing']['rules'] as List).cast<Map>()) {
      final matchers = rule.keys.where(
        (k) => !{'type', 'outboundTag', 'balancerTag', 'ruleTag'}.contains(k),
      );
      expect(matchers, isNotEmpty, reason: 'dangling rule: $rule');
    }
  });

  test('gate with a matching catalog keeps exactly the known categories', () {
    final catalog = GeoCatalog.fromJson({
      'site': [
        'geosite:category-ru',
        'geosite:category-gov-ru',
        'geosite:vk',
        'geosite:yandex',
        'geosite:youtube',
        // note: geosite:ok deliberately absent from the catalog
      ],
      'ip': ['geoip:ru'],
    });
    final gated = gate.prepare(
      parsedConfig,
      GeoState.ready(catalog: catalog, tag: 't', updatedAt: DateTime(2026)),
    );

    expect(gated, contains('geosite:category-ru'));
    expect(gated, contains('geoip:ru'));
    // the one category not in the catalog is gone
    expect(gated, isNot(contains('geosite:ok')));
    jsonDecode(gated); // still valid JSON
  });
}
