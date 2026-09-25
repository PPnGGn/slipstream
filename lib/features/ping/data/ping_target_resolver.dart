import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/ping/domain/entities/ping_target.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/xray_config_meta.dart';
import 'package:slipstream/features/subscriptions/data/vpn_server_display.dart';

/// Extracts a pingable endpoint from a server's stored xray config.
///
/// Returns null when the config has no host/port — such servers are
/// skipped by measurement runs.
@lazySingleton
class PingTargetResolver {
  const PingTargetResolver();

  PingTarget? resolve(VpnServer server) {
    final meta = server.meta;
    final host = meta.host;
    final port = meta.port;
    if (host == null || host.isEmpty || port == null) return null;

    return PingTarget(
      host: host,
      port: port,
      probe: _probeFor(meta.network),
      salamanderPassword: meta.network == 'hysteria'
          ? _salamanderPassword(server.configJson)
          : null,
    );
  }

  PingProbe _probeFor(String? network) => switch (network) {
    'hysteria' => PingProbe.quic,
    // mKCP is UDP with no reply to an unsolicited packet — there is
    // no honest probe for it, so it's never marked dead either.
    'kcp' => PingProbe.none,
    _ => PingProbe.tcp,
  };

  /// Reads `streamSettings.finalmask.udp[0].settings.password`, the
  /// obfs password xray_config_builder.buildHysteria2 emits for
  /// salamander obfuscation. Not part of [XrayServerMeta]: it's only
  /// needed here, to shape the ping probe.
  String? _salamanderPassword(String configJson) {
    try {
      final json = jsonDecode(configJson) as Map<String, dynamic>;
      final outbounds = (json['outbounds'] as List).cast<Map<String, dynamic>>();
      final proxy = outbounds.firstWhere((o) => (o['tag'] as String?) == 'proxy');
      final stream = proxy['streamSettings'] as Map<String, dynamic>?;
      final finalmask = stream?['finalmask'] as Map<String, dynamic>?;
      final udpMasks = finalmask?['udp'] as List?;
      if (udpMasks == null || udpMasks.isEmpty) return null;
      final salamander = udpMasks.cast<Map<String, dynamic>>().firstWhere(
        (m) => m['type'] == 'salamander',
        orElse: () => const {},
      );
      final settings = salamander['settings'] as Map<String, dynamic>?;
      return settings?['password'] as String?;
    } catch (_) {
      return null;
    }
  }
}
