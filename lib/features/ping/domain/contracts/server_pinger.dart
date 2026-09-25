import 'dart:io';

import 'package:slipstream/features/ping/domain/entities/ping_attempt_result.dart';
import 'package:slipstream/features/ping/domain/entities/ping_target.dart';

/// Contract for a single measurement attempt against one resolved
/// address. Implementations: TcpConnectPinger (real TCP handshake),
/// QuicProbePinger (QUIC Version Negotiation probe for hysteria2),
/// and test fakes.
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
