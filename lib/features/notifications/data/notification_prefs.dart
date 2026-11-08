import 'package:flutter/foundation.dart';

/// Which alerts the VPN service may show (Android). Both are on by default: an
/// alert that is off by default never reaches the person who needs it.
@immutable
class NotificationPrefs {
  const NotificationPrefs({
    this.trafficBlocked = true,
    this.startFailed = true,
  });

  /// The kill switch holds the traffic: the tunnel is gone and nothing gets
  /// out until the user reconnects.
  final bool trafficBlocked;

  /// The VPN could not start without the app (the quick settings tile,
  /// Always-on VPN, a restart of the service).
  final bool startFailed;

  NotificationPrefs copyWith({bool? trafficBlocked, bool? startFailed}) =>
      NotificationPrefs(
        trafficBlocked: trafficBlocked ?? this.trafficBlocked,
        startFailed: startFailed ?? this.startFailed,
      );

  @override
  bool operator ==(Object other) =>
      other is NotificationPrefs &&
      other.trafficBlocked == trafficBlocked &&
      other.startFailed == startFailed;

  @override
  int get hashCode => Object.hash(trafficBlocked, startFailed);

  @override
  String toString() =>
      'NotificationPrefs(trafficBlocked: $trafficBlocked, '
      'startFailed: $startFailed)';
}
