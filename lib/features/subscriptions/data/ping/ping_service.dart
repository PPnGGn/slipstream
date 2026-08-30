import 'dart:io';

import 'package:injectable/injectable.dart';

/// Lightweight TCP-connect latency probe with a short-lived cache, so that
/// re-expanding a subscription doesn't re-measure every server each time.
@lazySingleton
class PingService {
  static final Map<String, _Entry> _cache = {};
  static const _ttl = Duration(seconds: 45);
  static const _timeout = Duration(seconds: 3);

  Future<Duration?> ping(String host, int port) async {
    final key = '$host:$port';
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.at) < _ttl) {
      return cached.rtt;
    }

    final rtt = await _measure(host, port);
    _cache[key] = _Entry(DateTime.now(), rtt);
    return rtt;
  }

  Future<Duration?> _measure(String host, int port) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, port, timeout: _timeout);
      stopwatch.stop();
      socket.destroy();
      return stopwatch.elapsed;
    } catch (_) {
      return null;
    }
  }
}

class _Entry {
  _Entry(this.at, this.rtt);

  final DateTime at;
  final Duration? rtt;
}
