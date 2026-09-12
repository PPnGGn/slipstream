/// Whether Russian domains/IPs go direct instead of through the tunnel, for
/// servers that don't carry their own routing rules (a bare `vless://` link,
/// a hand-pasted config with no `routing` block). Provider subscriptions
/// bring their own split policy and are never touched — see
/// [RoutingPolicyGate].
enum RuBypassMode {
  /// Everything goes through the tunnel.
  off,

  /// Russian domains (`.ru` / `.рф`, `geosite:category-ru` &c.), Russian IP
  /// ranges and private ranges go direct; everything else through the tunnel.
  bypassRu;

  static RuBypassMode fromName(String? name) => RuBypassMode.values.firstWhere(
    (m) => m.name == name,
    orElse: () => RuBypassMode.bypassRu,
  );
}
