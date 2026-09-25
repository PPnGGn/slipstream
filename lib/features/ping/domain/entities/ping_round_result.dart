/// Outcome of a measurement round: `measured` = at least one
/// successful sample, `unreachable` = zero.
enum PingRoundStatus { measured, unreachable }

/// Why an unreachable round failed — drives the label shown next to
/// the dead-server indicator ("timeout", "refused", "no dns"...).
enum PingFailureReason { timeout, refused, dns, error }

/// Final result of one measurement round for a single server.
class PingRoundResult {
  const PingRoundResult({
    required this.status,
    required this.attemptCount,
    required this.successCount,
    this.latencyMs,
    this.failureReason,
  });

  final PingRoundStatus status;

  /// Total attempts actually made (the round may stop early after
  /// [maxConsecutiveFailures], so this can be less than [maxAttempts]).
  final int attemptCount;

  /// Successful attempts.
  final int successCount;

  /// Median of the successful samples, in ms. Null when no sample
  /// succeeded.
  final double? latencyMs;

  /// Set only when [status] is unreachable.
  final PingFailureReason? failureReason;
}
