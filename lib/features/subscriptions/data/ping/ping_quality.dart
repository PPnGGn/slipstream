/// Bucketed latency result, so the UI only has to map a bucket to a colour.
enum PingQuality {
  good,
  fair,
  poor,
  timeout;

  static PingQuality of(Duration? rtt) {
    if (rtt == null) return PingQuality.timeout;
    final ms = rtt.inMilliseconds;
    if (ms < 100) return PingQuality.good;
    if (ms < 250) return PingQuality.fair;
    return PingQuality.poor;
  }
}

/// Spreads the first probe of each tile over time so expanding a big
/// subscription doesn't open dozens of sockets at once.
Duration pingStagger(int index) => Duration(milliseconds: (index % 12) * 45);
