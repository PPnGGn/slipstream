import 'dart:io';

/// Resolves a ping target's hostname before any probe attempt.
///
/// Kept as its own step (instead of letting Socket.connect resolve
/// implicitly) so DNS latency never pollutes the measured RTT, and so
/// a dead/absent record is reported as its own failure reason instead
/// of a generic timeout.
abstract interface class HostResolver {
  /// Returns the resolved addresses, IPv4 first. Returns an empty
  /// list if [host] is not a literal IP and lookup fails or times out.
  Future<List<InternetAddress>> resolve(String host);
}
