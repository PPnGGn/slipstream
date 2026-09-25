/// Result of a SINGLE probe attempt. Every variant matters — success,
/// silence, active refusal and other network errors are distinct
/// diagnostic cases shown differently in the UI.
sealed class PingAttemptResult {
  const PingAttemptResult();
}

/// Probe answered. [durationMs] is the round-trip duration. Even
/// 400 ms is a success: slow is not the same as dead.
final class PingAttemptSuccess extends PingAttemptResult {
  const PingAttemptSuccess(this.durationMs);

  final double durationMs;
}

/// Server stayed silent for the whole attempt timeout.
final class PingAttemptTimedOut extends PingAttemptResult {
  const PingAttemptTimedOut();
}

/// Host actively refused the connection (RST on a closed port). Worth
/// telling apart from silence: the host is up, just not on this port.
final class PingAttemptRefused extends PingAttemptResult {
  const PingAttemptRefused();
}

/// Network-level error other than timeout/refusal (unreachable
/// network, socket setup failure, etc).
final class PingAttemptSocketError extends PingAttemptResult {
  const PingAttemptSocketError(this.error);

  final Object error;
}
