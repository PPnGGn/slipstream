/// How aggressively to blackhole ad / tracker domains for servers that carry
/// no routing policy of their own (a bare `vless://` link, hand-pasted JSON).
/// Provider subscriptions handle ads themselves and are never touched — see
/// [RoutingPolicyGate].
enum AdBlockMode {
  /// No ad-block rule injected.
  off,

  /// `geosite:category-ads` — v2fly's own core ad/tracker-network list,
  /// ~830 domains, ~0.15 MB resident once xray builds the matcher. Safe even
  /// on a memory-constrained process (an iOS Network Extension, ~50 MB cap).
  basic,

  /// `geosite:category-ads-all` — RunetFreedom's full easylist/adguard
  /// superset, ~149k domains. Measured cost: ~34 MB resident (xray builds a
  /// right-to-left label trie; ~82k of its nodes carry a near-empty Go map,
  /// ~256 B of overhead each) plus ~10 MB transient at load time. Fine for a
  /// normal process (Android's VPN service is the app's main process); can
  /// push an iOS Network Extension past its jetsam limit.
  full;

  /// The `geosite:` token this mode injects, or `null` for [off].
  String? get token => switch (this) {
    AdBlockMode.off => null,
    AdBlockMode.basic => 'geosite:category-ads',
    AdBlockMode.full => 'geosite:category-ads-all',
  };

  bool get enabled => this != AdBlockMode.off;

  static AdBlockMode fromName(String? name) => AdBlockMode.values.firstWhere(
    (m) => m.name == name,
    orElse: () => AdBlockMode.off,
  );
}
