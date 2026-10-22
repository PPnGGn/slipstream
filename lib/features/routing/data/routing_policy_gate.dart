import 'dart:convert';
import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/routing/data/ad_block_mode.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';

/// What [RoutingPolicyGate.apply] produced: the config, and whether it now
/// answers the system's DNS itself (passed on as `VpnConfigMessage.hijackDns`
/// so the tunnel can hand the OS a DNS address that only the config serves).
typedef PolicyResult = ({String configJson, bool hijacksDns});

/// Injects the client's own DNS + routing policy into a server config
/// immediately before it goes to the core — but only for servers that don't
/// carry a routing policy of their own (a `vless://` link's built scaffold, a
/// hand-pasted JSON with no rules). Provider subscriptions bring their own
/// split policy and keep it; the one thing added to them is the port-53 hijack
/// when they also bring resolvers of their own (see [_hijackProviderDns]).
///
/// For such configs the gate always installs:
///  - its own `dns` block: a remote DoH resolver reached through the tunnel,
///    plus Yandex DoH for Russian domains when [RuBypassMode.bypassRu] is on;
///  - a `dns-out` outbound that answers the system's DNS (port 53 on the
///    `socks` inbound) from that resolver, and drops AAAA / HTTPS records;
///  - rules that stop apps from going around it (QUIC, public DNS by IP, DoH
///    hostnames) and keep LAN traffic direct.
/// Two settings add to that:
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

  /// Tag of the inbound the core puts in front of tun2socks. Owned by
  /// slipstream-core (`localInbounds`); the DNS hijack rule below depends on it.
  static const _socksInboundTag = 'socks';

  /// Fallback tag for the proxy outbound when the config's first outbound has
  /// none (xray sends unmatched traffic to the first outbound).
  static const _defaultProxyTag = 'proxy';

  // DoH by IP, so resolving the resolver itself never needs DNS.
  static const _remoteDoh = 'https://8.8.8.8/dns-query';
  static const _ruDoh = 'https://77.88.8.8/dns-query';

  /// Domains whose names the Yandex resolver answers when bypassRu is on.
  static const _ruDomains = [
    'domain:ru',
    'domain:xn--p1ai',
    'geosite:category-ru',
    'geosite:category-gov-ru',
  ];

  /// Well-known public resolvers. Plain DNS (53) and DoH (443) to them is
  /// blocked so apps fall back to the system resolver, i.e. to us. DoT (853)
  /// is left open on purpose: Android's strict Private DNS uses it and does
  /// not fall back, so blocking it would kill DNS for those users. It still
  /// goes through the tunnel, so nothing leaks to the ISP.
  static const _publicDnsIps = [
    '8.8.8.8',
    '8.8.4.4',
    '1.1.1.1',
    '1.0.0.1',
    '9.9.9.9',
    '149.112.112.112',
    '208.67.222.222',
    '208.67.220.220',
    '94.140.14.14',
    '94.140.15.15',
    '77.88.8.8',
    '77.88.8.1',
    '2001:4860:4860::8888',
    '2001:4860:4860::8844',
    '2606:4700:4700::1111',
    '2606:4700:4700::1001',
  ];

  /// Hostnames browsers use for built-in DoH ("Secure DNS"). Blocked on 443
  /// only, for the same Private DNS reason as above (dns.google is also the
  /// usual DoT hostname).
  static const _dohDomains = [
    'domain:dns.google',
    'domain:cloudflare-dns.com',
    'domain:one.one.one.one',
    'domain:dns.quad9.net',
    'domain:doh.opendns.com',
    'domain:dns.adguard-dns.com',
    'domain:dns.nextdns.io',
    'domain:doh.dns.sb',
  ];

  /// [privateDnsStrict]: the OS runs strict Private DNS. Provider configs then
  /// keep their DNS untouched: the OS only asks the tunnel for the DoT server's
  /// own name, and a provider `dns.hosts` that blackholes DoH/DoT names (a
  /// common anti-bypass trick) would answer 0.0.0.0 and leave the phone with
  /// no DNS at all. Our own configs have no such entries and keep the hijack.
  PolicyResult apply(
    String configJson, {
    required RuBypassMode split,
    required AdBlockMode adBlock,
    bool privateDnsStrict = false,
  }) {
    final untouched = (configJson: configJson, hijacksDns: false);

    final Map<String, dynamic> config;
    try {
      config = jsonDecode(configJson) as Map<String, dynamic>;
    } catch (_) {
      return untouched; // let the core surface a decode error
    }

    if (_hasOwnRouting(config)) {
      if (privateDnsStrict || !_hijackProviderDns(config)) {
        _talker.debug(
          'RoutingPolicy: config routes by destination, left as is',
        );
        return untouched;
      }
      _talker.debug(
        'RoutingPolicy: provider routing kept, system DNS hijacked into its dns',
      );
      return (configJson: jsonEncode(config), hijacksDns: true);
    }

    final proxyTag = _ensureProxyTag(config);
    if (proxyTag == null) {
      return untouched; // no outbounds at all; let the core surface it
    }

    final bypassRu = split == RuBypassMode.bypassRu;
    final adToken = adBlock.token;

    config['dns'] = _dns(bypassRu: bypassRu);

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
    final injected = _policyRules(
      proxyTag: proxyTag,
      bypassRu: bypassRu,
      adToken: adToken,
    );
    routing['rules'] = [...injected, ...rules];
    config['routing'] = routing;

    _ensureOutbound(config, {'tag': 'direct', 'protocol': 'freedom'});
    _ensureOutbound(config, {'tag': 'block', 'protocol': 'blackhole'});
    _ensureOutbound(config, _dnsOutbound);

    _talker.debug(
      'RoutingPolicy: injected dns + ${injected.length} rule(s) '
      '(bypassRu=$bypassRu, adBlock=${adBlock.name})',
    );
    return (configJson: jsonEncode(config), hijacksDns: true);
  }

  bool _hasOwnRouting(Map<String, dynamic> config) {
    final rules = switch (config['routing']) {
      {'rules': final List<dynamic> l} => l,
      _ => const <dynamic>[],
    };
    return rules.any((r) => r is Map && r.keys.any(_matcherKeys.contains));
  }

  /// Makes a provider config answer the system's DNS from its own `dns` block:
  /// prepends the port-53 hijack and makes sure a `dns` outbound exists.
  /// Nothing else in its routing changes.
  ///
  /// Only when the config has a resolver that goes through xray's routing.
  /// With no `dns` block (or only `localhost` / `+local` ones) xray would
  /// resolve via the system from its own process — which is excluded from the
  /// tunnel — so hijacking would leak every query to the ISP. Those configs
  /// keep the public system DNS, reached through the tunnel. Returns whether
  /// the hijack was installed.
  bool _hijackProviderDns(Map<String, dynamic> config) {
    if (!_hasRoutedResolver(config)) return false;
    final rules = (config['routing'] as Map)['rules'] as List;
    rules.insert(0, _dnsHijackRule(_ensureDnsOutboundTag(config)));
    return true;
  }

  static bool _hasRoutedResolver(Map<String, dynamic> config) {
    final servers = switch (config['dns']) {
      {'servers': final List<dynamic> l} => l,
      _ => const <dynamic>[],
    };
    return servers.any((server) {
      final address = switch (server) {
        final String a => a,
        {'address': final String a} => a,
        _ => null,
      };
      if (address == null) return false;
      final a = address.toLowerCase();
      return a != 'localhost' && a != 'fakedns' && !a.contains('+local');
    });
  }

  /// Tag of the config's own `dns` outbound if it has one, otherwise adds a
  /// plain one. Plain = xray's default: A/AAAA answered from the `dns` block,
  /// other types get an empty answer.
  String _ensureDnsOutboundTag(Map<String, dynamic> config) {
    final outbounds = switch (config['outbounds']) {
      final List<dynamic> l => l,
      _ => <dynamic>[],
    };
    config['outbounds'] = outbounds;
    for (final o in outbounds) {
      if (o is Map && o['protocol'] == 'dns' && o['tag'] is String) {
        return o['tag'] as String;
      }
    }
    final taken = {
      for (final o in outbounds)
        if (o is Map) o['tag'],
    };
    final tag = taken.contains('dns-out') ? 'slipstream-dns-out' : 'dns-out';
    outbounds.add(<String, dynamic>{'tag': tag, 'protocol': 'dns'});
    return tag;
  }

  /// Tag of the first outbound — where xray sends anything no rule matched,
  /// i.e. the proxy. Assigns [_defaultProxyTag] if it has none, so rules can
  /// point at it. Null when there are no outbounds.
  String? _ensureProxyTag(Map<String, dynamic> config) {
    final outbounds = config['outbounds'];
    if (outbounds is! List || outbounds.isEmpty || outbounds.first is! Map) {
      return null;
    }
    final first = outbounds.first as Map;
    final tag = first['tag'];
    if (tag is String && tag.isNotEmpty) return tag;
    first['tag'] = _defaultProxyTag;
    return _defaultProxyTag;
  }

  static Map<String, dynamic> _dns({required bool bypassRu}) => {
    'servers': [
      if (bypassRu)
        {
          'tag': 'dns-ru',
          'address': _ruDoh,
          'domains': _ruDomains,
          // A Russian answer only; anything else falls through to remote.
          'expectIPs': ['geoip:ru'],
          // Never used for names outside _ruDomains.
          'skipFallback': true,
        },
      {'tag': 'dns-remote', 'address': _remoteDoh},
    ],
    'queryStrategy': 'UseIPv4',
  };

  /// Answers A queries from the `dns` block above; AAAA (28) and HTTPS (65)
  /// get an empty answer: everything goes over IPv4, and no ECH keys that
  /// would hide the TLS server name from sniffing (and so from domain rules).
  static const Map<String, dynamic> _dnsOutbound = {
    'tag': 'dns-out',
    'protocol': 'dns',
    'settings': {
      'rules': [
        {'action': 'return', 'qType': '28,65'},
      ],
    },
  };

  /// The injected rules, first match wins. The order is the point:
  ///  - the resolver's own queries (dns-ru / dns-remote) come first, or the
  ///    public-DNS block below would catch dns-remote's request to 8.8.8.8;
  ///  - the port-53 hijack comes before anything matching by IP, or a query to
  ///    a private address would be sent direct by geoip:private;
  ///  - blocks come before the direct rules, so an ad domain on a .ru site is
  ///    still blocked.
  static List<Map<String, dynamic>> _policyRules({
    required String proxyTag,
    required bool bypassRu,
    required String? adToken,
  }) => [
    if (bypassRu)
      {
        'type': 'field',
        'inboundTag': ['dns-ru'],
        'outboundTag': 'direct',
        'ruleTag': 'dns-ru',
      },
    {
      'type': 'field',
      'inboundTag': ['dns-remote'],
      'outboundTag': proxyTag,
      'ruleTag': 'dns-remote',
    },
    _dnsHijackRule('dns-out'),
    // QUIC: blocked so browsers fall back to TLS over TCP, whose server name
    // sniffing can read.
    {
      'type': 'field',
      'network': 'udp',
      'port': '443',
      'outboundTag': 'block',
      'ruleTag': 'block-quic',
    },
    {
      'type': 'field',
      'protocol': ['bittorrent'],
      'outboundTag': 'direct',
      'ruleTag': 'bittorrent-direct',
    },
    {
      'type': 'field',
      'ip': _publicDnsIps,
      'port': '53,443',
      'outboundTag': 'block',
      'ruleTag': 'block-public-dns',
    },
    {
      'type': 'field',
      'domain': _dohDomains,
      'port': '443',
      'outboundTag': 'block',
      'ruleTag': 'block-doh',
    },
    if (adToken != null)
      {
        'type': 'field',
        'domain': [adToken],
        'outboundTag': 'block',
        'ruleTag': 'ad-block',
      },
    // Three separate rules: xray ANDs the conditions inside one rule, so
    // domain and ip matchers must live in separate rules to act as OR.
    if (bypassRu)
      {
        'type': 'field',
        'domain': [..._ruDomains, 'geosite:private'],
        'outboundTag': 'direct',
        'ruleTag': 'ru-bypass-domain',
      },
    {
      'type': 'field',
      'ip': ['geoip:private'],
      'outboundTag': 'direct',
      'ruleTag': 'private-direct',
    },
    if (bypassRu)
      {
        'type': 'field',
        'ip': ['geoip:ru'],
        'outboundTag': 'direct',
        'ruleTag': 'ru-bypass-ip',
      },
    // Everything else: no rule, xray's default is the first outbound (proxy).
  ];

  /// The system's DNS (anything to port 53 coming from tun2socks) goes to the
  /// config's resolvers instead of wherever the OS sent it.
  static Map<String, dynamic> _dnsHijackRule(String dnsOutboundTag) => {
    'type': 'field',
    'inboundTag': [_socksInboundTag],
    'port': '53',
    'outboundTag': dnsOutboundTag,
    'ruleTag': 'dns-hijack',
  };

  /// Adds [outbound] unless one with the same tag is already there.
  void _ensureOutbound(
    Map<String, dynamic> config,
    Map<String, dynamic> outbound,
  ) {
    final existing = config['outbounds'];
    final outbounds = existing is List<dynamic> ? existing : <dynamic>[];
    config['outbounds'] = outbounds;

    final tag = outbound['tag'];
    final has = outbounds.any((o) => o is Map && o['tag'] == tag);
    if (!has) outbounds.add(<String, dynamic>{...outbound});
  }
}
