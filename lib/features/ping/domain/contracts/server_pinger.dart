import 'dart:io';

import 'package:slipstream/features/ping/domain/entities/ping_attempt_result.dart';
import 'package:slipstream/features/ping/domain/entities/ping_target.dart';

/// Contract for a single measurement attempt against one resolved
/// address. Implementations: TcpConnectPinger (real TCP handshake),
/// QuicProbePinger (QUIC Version Negotiation probe for hysteria2),
/// and test fakes.
///
/// Probes always go straight to the server, never through the VPN: they
/// are raw OS sockets (no HttpClient, so no proxy can apply), and the VPN
/// service excludes the app's own package from the tunnel
/// (`addDisallowedApplication` in V2RayVpnService.kt). With the tunnel up
/// the number stays the device-to-server latency, not the latency of a
/// detour through the connected server.
abstract interface class ServerPinger {
  /// Probes [address]:[target.port], measures how long it takes to
  /// get a response, and tears everything down without exchanging
  /// any protocol-level data.
  ///
  /// Must give up after [timeout] even if the OS/network stays silent.
  Future<PingAttemptResult> ping({
    required PingTarget target,
    required InternetAddress address,
    required Duration timeout,
  });
}
