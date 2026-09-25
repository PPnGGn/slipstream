import 'package:slipstream/features/ping/domain/entities/ping_round_result.dart';

/// Per-server latency display state, derived from round results.
///
/// [queued] and [measuring] are shown identically (a pulsing
/// placeholder) but kept distinct so the cubit's worker pool can tell
/// "waiting for a free slot" from "socket open right now" — useful
/// for diagnosing a stuck run, not currently shown differently in UI.
enum PingRunStatus { notTested, queued, measuring, measured, dead, unsupported }

enum PingQuality { good, medium, poor }

/// Thresholds from the design (see design/SlipStream Design.dc.html's
/// `latCol`): green below 80 ms, red above 160 ms.
const double pingGoodBelowMs = 80;
const double pingPoorAboveMs = 160;

PingQuality pingQualityOf(double latencyMs) => latencyMs < pingGoodBelowMs
    ? PingQuality.good
    : latencyMs > pingPoorAboveMs
    ? PingQuality.poor
    : PingQuality.medium;

class PingEntry {
  const PingEntry({
    required this.status,
    this.latencyMs,
    this.attemptCount = 0,
    this.successCount = 0,
    this.failureReason,
  });

  const PingEntry.notTested() : this(status: PingRunStatus.notTested);
  const PingEntry.queued() : this(status: PingRunStatus.queued);
  const PingEntry.measuring() : this(status: PingRunStatus.measuring);

  /// No probe exists for this server's transport (mKCP): never
  /// attempted, so it must never read as "dead".
  const PingEntry.unsupported() : this(status: PingRunStatus.unsupported);

  final PingRunStatus status;

  /// Median latency in ms; null while unmeasured or dead.
  final double? latencyMs;

  final int attemptCount;
  final int successCount;

  /// Set only when [status] is dead — drives the label next to the
  /// dead indicator ("timeout", "refused", "no dns").
  final PingFailureReason? failureReason;
}
