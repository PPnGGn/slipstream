/// The resolver the tunnel asks for names it has to look up itself: queries
/// travel through the VPN server, so the ISP never sees them.
///
/// [address] is written into the `dns-remote` server of the xray config as is
/// (see RoutingPolicyGate). Resolvers are given by IP, so finding the resolver
/// never needs DNS itself.
enum RemoteDns {
  /// DNS over HTTPS to Cloudflare.
  cloudflare('https://1.1.1.1/dns-query'),

  /// DNS over HTTPS to Google. The default: what the app has always used.
  google('https://8.8.8.8/dns-query'),

  /// Plain UDP port 53 to Cloudflare, through the tunnel. xray's own, simplest
  /// resolver: no TLS handshake, but the server (not the ISP) sees it in clear.
  xray('1.1.1.1');

  const RemoteDns(this.address);

  final String address;

  /// The option stored under [name]; [google] for null and unknown names.
  static RemoteDns fromName(String? name) => RemoteDns.values.firstWhere(
    (v) => v.name == name,
    orElse: () => RemoteDns.google,
  );
}
