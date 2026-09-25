/// Which probe kind reaches this server's protocol honestly.
enum PingProbe {
  /// TCP-based protocols (vless/vmess/trojan/shadowsocks over
  /// tcp/ws/grpc/xhttp without h3): a raw TCP handshake is the real
  /// thing the proxy itself needs to establish.
  tcp,

  /// QUIC/UDP-based protocols (hysteria2, xhttp with h3 alpn): a TCP
  /// probe against the same host proves nothing, since nothing there
  /// speaks TCP. Probed instead with a QUIC long-header packet that
  /// forces a Version Negotiation reply.
  quic,

  /// No probe can reach this transport honestly (kcp: UDP with no
  /// unsolicited-packet reply). Shown as "not supported", never as
  /// "dead" — we simply never tried.
  none,
}

/// Where to ping a server and how to do it.
class PingTarget {
  const PingTarget({
    required this.host,
    required this.port,
    required this.probe,
    this.salamanderPassword,
  });

  final String host;
  final int port;
  final PingProbe probe;

  /// Salamander obfuscation password, when the hysteria2 config uses
  /// it (`finalmask.udp[type=salamander]`). Without deobfuscating the
  /// probe with the same key, the server never even parses it as a
  /// QUIC packet.
  final String? salamanderPassword;
}
