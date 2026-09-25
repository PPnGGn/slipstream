import 'package:injectable/injectable.dart';
import 'package:slipstream/features/ping/domain/contracts/host_resolver.dart';
import 'package:slipstream/features/ping/domain/contracts/server_pinger.dart';
import 'package:slipstream/features/ping/domain/entities/ping_attempt_result.dart';
import 'package:slipstream/features/ping/domain/entities/ping_round_result.dart';
import 'package:slipstream/features/ping/domain/entities/ping_target.dart';
import 'package:slipstream/features/ping/domain/ping_constants.dart';

/// Runs one measurement round against a single server: up to
/// [maxAttempts] probes, stopping early after [maxConsecutiveFailures]
/// in a row. Deliberately short — this is a liveness probe, not a
/// load test, and hammering a server with dozens of connections per
/// round is what makes its own rate limiting mistake it for an attack
/// (the actual cause of "reachable servers show up as dead").
///
/// Callers are expected to only invoke this for targets whose probe
/// is tcp or quic — [PingProbe.none] targets have no honest probe and
/// should never reach here (see PingCubit).
@lazySingleton
class MeasurePingUseCase {
  MeasurePingUseCase(
    @Named('tcp') this._tcpPinger,
    @Named('quic') this._quicPinger,
    this._resolver,
  );

  final ServerPinger _tcpPinger;
  final ServerPinger _quicPinger;
  final HostResolver _resolver;

  Future<PingRoundResult> measure(PingTarget target) async {
    final addresses = await _resolver.resolve(target.host);
    if (addresses.isEmpty) {
      return const PingRoundResult(
        status: PingRoundStatus.unreachable,
        attemptCount: 0,
        successCount: 0,
        failureReason: PingFailureReason.dns,
      );
    }

    final pinger = target.probe == PingProbe.quic ? _quicPinger : _tcpPinger;
    final samples = <double>[];
    var attemptCount = 0;
    var consecutiveFailures = 0;
    var lastFailure = PingFailureReason.timeout;

    for (var i = 0; i < maxAttempts; i++) {
      // Round-robins through every resolved address, not just the
      // first: a silent failure on one moves on to the next instead
      // of retrying the same (possibly broken) route, which matters
      // most for mixed IPv4/IPv6 hosts with one dead family.
      final address = addresses[i % addresses.length];
      attemptCount++;

      final attempt = await pinger.ping(
        target: target,
        address: address,
        timeout: const Duration(milliseconds: attemptTimeoutMs),
      );

      switch (attempt) {
        case PingAttemptSuccess(:final durationMs):
          samples.add(durationMs);
          consecutiveFailures = 0;
        case PingAttemptTimedOut():
          consecutiveFailures++;
          lastFailure = PingFailureReason.timeout;
        case PingAttemptRefused():
          consecutiveFailures++;
          lastFailure = PingFailureReason.refused;
        case PingAttemptSocketError():
          consecutiveFailures++;
          lastFailure = PingFailureReason.error;
      }

      if (consecutiveFailures >= maxConsecutiveFailures) break;
    }

    if (samples.isEmpty) {
      return PingRoundResult(
        status: PingRoundStatus.unreachable,
        attemptCount: attemptCount,
        successCount: 0,
        failureReason: lastFailure,
      );
    }

    return PingRoundResult(
      status: PingRoundStatus.measured,
      attemptCount: attemptCount,
      successCount: samples.length,
      latencyMs: _median(samples),
    );
  }

  /// Median instead of a mean/EMA: with at most 3 samples an
  /// exponential average barely has anything to smooth and just lags
  /// behind the true value, while the median shrugs off a single
  /// one-off spike outright.
  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }
}
