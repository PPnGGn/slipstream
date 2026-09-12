import 'dart:convert';
import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/routing/data/ad_block_mode.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';

/// Injects the client's own routing policy into a server config immediately
/// before it goes to the core — but only for servers that don't carry a routing
/// policy of their own (a `vless://` link's built scaffold, a hand-pasted JSON
/// with no rules). Provider subscriptions bring their own split policy and are
/// left untouched.
///
/// Two independent settings feed this gate:
///  - [RuBypassMode.bypassRu] — Russian domains / IPs go direct.
///  - [AdBlockMode] — the matching `geosite:category-ads*` token is blackholed.
///
/// Runs at connect time, right before [GeoConfigGate], for the same reason that
/// gate does: the policy is runtime state the user can flip, while a
/// subscription is parsed once. Injecting here also means the decision is made
/// on the *final* config, uniform whether the server came from a `vless://`
/// link or a hand-pasted JSON.
///
/// Order matters: this gate adds `geosite:`/`geoip:` tokens; [GeoConfigGate]
/// runs next and strips the ones the installed `.dat` can't resolve, leaving
/// the `.ru` / `.рф` suffix rules (which need no geo data) as the floor.
@lazySingleton
class RoutingPolicyGate {
  RoutingPolicyGate(this._talker);

  final Talker _talker;

  /// Keys that make a routing rule count as "the config already routes by
  /// destination" — i.e. it brought its own policy, leave it alone.
  static const _matcherKeys = {'domain', 'domains', 'ip', 'geoip'};

  String apply(
    String configJson, {
    required RuBypassMode split,
    required AdBlockMode adBlock,
  }) {
    if (split == RuBypassMode.off && !adBlock.enabled) return configJson;

    final Map<String, dynamic> config;
    try {
      config = jsonDecode(configJson) as Map<String, dynamic>;
    } catch (_) {
      return configJson; // let the core surface a decode error
    }

    if (_hasOwnRouting(config)) {
      _talker.debug('RoutingPolicy: config routes by destination, left as is');
      return configJson;
    }

    final routing = switch (config['routing']) {
      final Map<String, dynamic> r => r,
      _ => <String, dynamic>{},
    };
    routing['domainStrategy'] ??= 'IPIfNonMatch'; // resolve so geoip:ru can hit
    routing['domainMatcher'] ??= 'hybrid';
    final rules = switch (routing['rules']) {
      final List<dynamic> l => l,
      _ => <dynamic>[],
    };

    final adToken = adBlock.token;
    final injected = <Map<String, dynamic>>[
      if (adToken != null) _adBlockRule(adToken),
      if (split == RuBypassMode.bypassRu) ..._ruBypassRules(),
    ];
    routing['rules'] = [...injected, ...rules];
    config['routing'] = routing;

    _ensureOutbound(config, 'direct', 'freedom');
    if (adToken != null) _ensureOutbound(config, 'block', 'blackhole');

    _talker.debug(
      'RoutingPolicy: injected ${injected.length} rule(s) '
      '(bypassRu=${split == RuBypassMode.bypassRu}, adBlock=${adBlock.name})',
    );
    return jsonEncode(config);
  }

  bool _hasOwnRouting(Map<String, dynamic> config) {
    final rules = switch (config['routing']) {
      {'rules': final List<dynamic> l} => l,
      _ => const <dynamic>[],
    };
    return rules.any((r) => r is Map && r.keys.any(_matcherKeys.contains));
  }

  // Blackholed ads go first so an ad domain hosted on a .ru site is still
  // blocked rather than sent direct by the RU-bypass rule below it.
  static Map<String, dynamic> _adBlockRule(String token) => {
    'type': 'field',
    'domain': [token],
    'outboundTag': 'block',
    'ruleTag': 'ad-block',
  };

  // Three independent rules (xray ANDs the conditions inside one rule, so
  // domain and ip matchers must live in separate rules to act as OR).
  static List<Map<String, dynamic>> _ruBypassRules() => [
    {
      'type': 'field',
      'protocol': ['bittorrent'],
      'outboundTag': 'direct',
      'ruleTag': 'ru-bypass-bittorrent',
    },
    {
      'type': 'field',
      'ip': ['geoip:private', 'geoip:ru'],
      'outboundTag': 'direct',
      'ruleTag': 'ru-bypass-ip',
    },
    {
      'type': 'field',
      'domain': [
        'domain:ru',
        'domain:xn--p1ai',
        'geosite:category-ru',
        'geosite:category-gov-ru',
        'geosite:private',
      ],
      'outboundTag': 'direct',
      'ruleTag': 'ru-bypass-domain',
    },
  ];

  void _ensureOutbound(
    Map<String, dynamic> config,
    String tag,
    String protocol,
  ) {
    final existing = config['outbounds'];
    final outbounds = existing is List<dynamic> ? existing : <dynamic>[];
    config['outbounds'] = outbounds;

    final has = outbounds.any((o) => o is Map && (o['tag'] as String?) == tag);
    if (!has) {
      outbounds.add(<String, dynamic>{'protocol': protocol, 'tag': tag});
    }
  }
}
