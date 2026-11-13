/// Where one server stands in the "Real delay" check: a request sent through
/// it by the core, not a connect to its port (that is the ping, see
/// ping_entry.dart).
enum RealDelayStatus { notTested, measuring, measured, failed }

/// Why a check failed. The user learns only "no answer in time" or "something
/// else"; the core's own text goes to the log.
enum RealDelayFailure { timeout, other }

enum RealDelayTier { good, medium, poor }

/// Its own thresholds, not the ping's (80 and 160 ms): a request through the
/// server includes the handshake with it, the exit and the way back, so the
/// numbers are several times larger on a server that is fine.
const int realDelayGoodBelowMs = 300;
const int realDelayPoorAboveMs = 700;

RealDelayTier realDelayTierOf(int latencyMs) => latencyMs < realDelayGoodBelowMs
    ? RealDelayTier.good
    : latencyMs > realDelayPoorAboveMs
    ? RealDelayTier.poor
    : RealDelayTier.medium;

class RealDelayEntry {
  const RealDelayEntry._(this.status, {this.latencyMs, this.failure});

  const RealDelayEntry.notTested() : this._(RealDelayStatus.notTested);
  const RealDelayEntry.measuring() : this._(RealDelayStatus.measuring);
  const RealDelayEntry.measured(int latencyMs)
    : this._(RealDelayStatus.measured, latencyMs: latencyMs);
  const RealDelayEntry.failed(RealDelayFailure failure)
    : this._(RealDelayStatus.failed, failure: failure);

  final RealDelayStatus status;

  /// Set only when [status] is measured.
  final int? latencyMs;

  /// Set only when [status] is failed.
  final RealDelayFailure? failure;
}
