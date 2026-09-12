import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// The loopback port an HTTP proxy inbound is listening on for the currently
/// active connection, or `null` when nothing is connected.
///
/// Written by `VpnRepository.start` / `stop`; read by anything that wants to
/// route its own traffic through the live tunnel (see [buildProxiedClient]).
/// The app is excluded from the OS-level tunnel, so this is the only path in.
@lazySingleton
class LocalProxyPort {
  int? value;
}

/// Guarantees a server config exposes a loopback HTTP proxy inbound and
/// reports the port it's on.
///
/// This runs at connect time, ahead of `RoutingPolicyGate` / `GeoConfigGate`.
/// It lives apart from `RoutingPolicyGate` on purpose: that gate returns the
/// config untouched when the server brought its own routing policy, whereas
/// the inbound is needed unconditionally.
///
/// Most real configs already carry an `http` inbound on `127.0.0.1:10809`
/// (both the `vless://` scaffold and Remnawave panel exports do), so the
/// common path is a no-op that just reads the existing port back.
@lazySingleton
class LocalProxyGate {
  LocalProxyGate(this._talker);

  final Talker _talker;

  static const _fallbackPort = 10809;
  static const _loopback = {'127.0.0.1', 'localhost', '::1'};

  /// Returns `(config, port)` — the config unchanged if it already has a
  /// usable loopback `http` inbound, otherwise a copy with one appended.
  (String, int) ensureHttpInbound(String configJson) {
    final Map<String, dynamic> config;
    try {
      config = jsonDecode(configJson) as Map<String, dynamic>;
    } catch (_) {
      return (configJson, _fallbackPort); // let the core surface the decode error
    }

    final inbounds = switch (config['inbounds']) {
      final List<dynamic> l => l,
      _ => <dynamic>[],
    };

    for (final inbound in inbounds) {
      if (inbound is! Map) continue;
      if (inbound['protocol'] != 'http') continue;
      final listen = inbound['listen'];
      if (listen is String && !_loopback.contains(listen)) continue;
      final port = inbound['port'];
      if (port is int) return (configJson, port);
    }

    final port = _firstFreePort(inbounds);
    final updated = {
      ...config,
      'inbounds': [
        ...inbounds,
        {
          'listen': '127.0.0.1',
          'port': port,
          'protocol': 'http',
          'settings': {'userLevel': 8},
          'tag': 'geo-bootstrap-http',
        },
      ],
    };
    _talker.debug(
      'LocalProxy: config had no loopback http inbound, added one on 127.0.0.1:$port',
    );
    return (jsonEncode(updated), port);
  }

  int _firstFreePort(List<dynamic> inbounds) {
    final taken = {
      for (final i in inbounds)
        if (i is Map && i['port'] is int) i['port'] as int,
    };
    var port = _fallbackPort;
    while (taken.contains(port)) {
      port++;
    }
    return port;
  }
}
