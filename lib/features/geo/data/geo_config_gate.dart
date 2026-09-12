import 'dart:convert';
import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/geo/cubit/geo_cubit.dart';

/// Rewrites `geosite:` / `geoip:` references in a server config for the geo data
/// that is *actually installed right now*, immediately before the config goes
/// to the core.
///
/// This lives at connect time, not parse time, on purpose: whether a token can
/// be kept depends on runtime state (are the .dat files downloaded? which
/// categories do they contain?), which changes independently of when a
/// subscription was parsed. The parser keeps every geo token verbatim; this
/// gate is the single place that decides keep-or-strip.
///
/// xray-core hard-fails to build a config that names a `geosite:`/`geoip:`
/// category it can't load, so an unknown token must be removed — and a routing
/// rule or DNS server left with nothing to match after that is removed too.
@lazySingleton
class GeoConfigGate {
  GeoConfigGate(this._talker);

  final Talker _talker;

  static const _ruleMetaKeys = {'type', 'outboundTag', 'balancerTag', 'ruleTag'};

  // routing.rules[] fields xray-core routes through geodata.ParseDomainRules /
  // ParseIPRules (infra/conf/router.go): `domain`/`domains` for site tokens,
  // `ip` plus the source/local IP aliases for IP tokens. `source` is an alias
  // xray folds into `sourceIP` when both are absent — gate it too so a config
  // using the older spelling isn't missed.
  static const _routingGeoFields = {
    'domain',
    'domains',
    'ip',
    'source',
    'sourceIP',
    'localIP',
  };

  // dns.servers[] fields xray-core routes through geodata (infra/conf/dns.go):
  // `domains` scopes a resolver to certain domains, `expectIPs`/`expectedIPs`/
  // `unexpectedIPs` filter which resolved IPs are accepted. `geoip` isn't a
  // NameServerConfig field in this xray-core version — kept out on purpose.
  static const _dnsServerGeoFields = {
    'domains',
    'expectIPs',
    'expectedIPs',
    'unexpectedIPs',
  };

  // inbounds[].sniffing fields xray-core routes through geodata
  // (infra/conf/xray.go SniffingConfig.Build): domainsExcluded / ipsExcluded.
  static const _sniffingFields = {'domainsExcluded', 'ipsExcluded'};

  String prepare(String configJson, GeoState geo) {
    final Map<String, dynamic> config;
    try {
      config = jsonDecode(configJson) as Map<String, dynamic>;
    } catch (_) {
      return configJson; // let the core surface a decode error
    }

    final catalog = geo.catalog;
    bool keep(Object? token) {
      if (token is! String) return true;
      if (token.startsWith('ext:') || token.startsWith('ext-ip:')) {
        return false; // external .dat files are never available
      }
      if (!token.startsWith('geosite:') && !token.startsWith('geoip:')) {
        return true;
      }
      return geo.isReady && catalog.has(token);
    }

    var touched = _gateDns(config, keep);
    touched |= _gateRouting(config, keep);
    touched |= _gateSniffing(config, keep);

    if (!touched) return configJson;
    if (!geo.isReady) {
      _talker.debug('Geo: no data installed, stripped geo refs from config');
    }
    return jsonEncode(config);
  }

  // --- DNS ------------------------------------------------------------------

  bool _gateDns(Map<String, dynamic> config, bool Function(Object?) keep) {
    final dns = config['dns'];
    if (dns is! Map) return false;
    var touched = false;

    final hosts = dns['hosts'];
    if (hosts is Map) {
      final filtered = {
        for (final e in hosts.entries)
          if (keep(e.key)) e.key: e.value,
      };
      if (filtered.length != hosts.length) {
        dns['hosts'] = filtered;
        touched = true;
      }
    }

    final servers = dns['servers'];
    if (servers is List) {
      final kept = <dynamic>[];
      for (final server in servers) {
        if (server is! Map) {
          kept.add(server);
          continue;
        }
        var scopedThenEmptied = false;
        for (final field in _dnsServerGeoFields) {
          final list = server[field];
          if (list is! List) continue;
          final filtered = list.where(keep).toList();
          if (filtered.length == list.length) continue;
          touched = true;
          if (filtered.isEmpty) {
            server.remove(field);
            if (list.isNotEmpty) scopedThenEmptied = true;
          } else {
            server[field] = filtered;
          }
        }
        // A server that only scoped geo domains would silently become a
        // catch-all resolver — drop it.
        if (scopedThenEmptied && server['domains'] == null) {
          _talker.debug('Geo: dropped a DNS server scoped only to geo rules');
          continue;
        }
        kept.add(server);
      }
      if (kept.length != servers.length) {
        dns['servers'] = kept.isEmpty ? ['1.1.1.1', '8.8.8.8'] : kept;
      }
    }

    return touched;
  }

  // --- routing ------------------------------------------------------------

  bool _gateRouting(Map<String, dynamic> config, bool Function(Object?) keep) {
    final routing = config['routing'];
    if (routing is! Map) return false;
    final rules = routing['rules'];
    if (rules is! List) return false;

    var touched = false;
    final kept = <dynamic>[];
    for (final rule in rules) {
      if (rule is! Map) {
        kept.add(rule);
        continue;
      }
      for (final field in _routingGeoFields) {
        final list = rule[field];
        if (list is! List) continue;
        final filtered = list.where(keep).toList();
        if (filtered.length == list.length) continue;
        touched = true;
        if (filtered.isEmpty) {
          rule.remove(field);
        } else {
          rule[field] = filtered;
        }
      }
      final hasMatcher = rule.keys.any((k) => !_ruleMetaKeys.contains(k));
      if (!hasMatcher) {
        _talker.debug('Geo: dropped a routing rule left with nothing to match');
        touched = true;
        continue;
      }
      kept.add(rule);
    }

    if (touched) routing['rules'] = kept;
    return touched;
  }

  // --- sniffing -------------------------------------------------------------

  // inbounds[].sniffing.domainsExcluded / ipsExcluded accept geosite:/geoip:
  // tokens too (infra/conf/xray.go SniffingConfig.Build) — same fate as any
  // other unresolvable token if left in. The sniffing block itself is never
  // removed even if both lists end up empty; an inbound with sniffing enabled
  // and no exclusions is a perfectly normal config.
  bool _gateSniffing(Map<String, dynamic> config, bool Function(Object?) keep) {
    final inbounds = config['inbounds'];
    if (inbounds is! List) return false;

    var touched = false;
    for (final inbound in inbounds) {
      if (inbound is! Map) continue;
      final sniffing = inbound['sniffing'];
      if (sniffing is! Map) continue;

      for (final field in _sniffingFields) {
        final list = sniffing[field];
        if (list is! List) continue;
        final filtered = list.where(keep).toList();
        if (filtered.length == list.length) continue;
        touched = true;
        if (filtered.isEmpty) {
          sniffing.remove(field);
        } else {
          sniffing[field] = filtered;
        }
      }
    }
    return touched;
  }
}
