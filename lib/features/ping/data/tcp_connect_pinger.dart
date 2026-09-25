import 'dart:async';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:slipstream/features/ping/domain/contracts/server_pinger.dart';
import 'package:slipstream/features/ping/domain/entities/ping_attempt_result.dart';
import 'package:slipstream/features/ping/domain/entities/ping_target.dart';
import 'package:slipstream/features/ping/domain/ping_constants.dart';

/// Measures latency as the duration of a raw TCP handshake:
/// connect, measure, destroy the socket without sending any data.
@LazySingleton(as: ServerPinger)
@Named('tcp')
class TcpConnectPinger implements ServerPinger {
  @override
  Future<PingAttemptResult> ping({
    required PingTarget target,
    required InternetAddress address,
    required Duration timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(address, target.port, timeout: timeout);
      stopwatch.stop();
      socket.destroy();
      return PingAttemptSuccess(stopwatch.elapsedMicroseconds / 1000);
    } on TimeoutException {
      return const PingAttemptTimedOut();
    } on SocketException catch (e) {
      final osError = e.osError;
      if (osError != null) {
        if (osTimeoutErrorCodes.contains(osError.errorCode)) {
          return const PingAttemptTimedOut();
        }
        if (osConnectionRefusedErrorCodes.contains(osError.errorCode)) {
          return const PingAttemptRefused();
        }
      }
      return PingAttemptSocketError(e);
    }
  }
}
