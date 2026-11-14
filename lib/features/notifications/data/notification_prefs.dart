import 'package:flutter/foundation.dart';

/// Which alerts the app may show (Android). All are on by default: an alert
/// that is off by default never reaches the person who needs it.
///
/// The first three are shown by the VPN service (Kotlin keeps its own copy of
/// them, see NativePrefsRunner); [subscriptionFailed] is decided in Dart, by the
/// background job, which reads it from the store itself.
@immutable
class NotificationPrefs {
  const NotificationPrefs({
    this.trafficBlocked = true,
    this.startFailed = true,
    this.revoked = true,
    this.subscriptionFailed = true,
  });

  /// How many alerts there are. The Notifications row counts "N of this many
  /// on"; a new alert raises it.
  static const total = 4;

  /// The kill switch holds the traffic: the tunnel is gone and nothing gets
  /// out until the user reconnects.
  final bool trafficBlocked;

  /// The VPN could not start without the app (the quick settings tile,
  /// Always-on VPN, a restart of the service).
  final bool startFailed;

  /// Another VPN app took over while ours was up: the system revoked it.
  final bool revoked;

  /// The background refresh of a subscription failed.
  final bool subscriptionFailed;

  int get enabledCount => [
    trafficBlocked,
    startFailed,
    revoked,
    subscriptionFailed,
  ].where((on) => on).length;

  NotificationPrefs copyWith({
    bool? trafficBlocked,
    bool? startFailed,
    bool? revoked,
    bool? subscriptionFailed,
  }) => NotificationPrefs(
    trafficBlocked: trafficBlocked ?? this.trafficBlocked,
    startFailed: startFailed ?? this.startFailed,
    revoked: revoked ?? this.revoked,
    subscriptionFailed: subscriptionFailed ?? this.subscriptionFailed,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationPrefs &&
      other.trafficBlocked == trafficBlocked &&
      other.startFailed == startFailed &&
      other.revoked == revoked &&
      other.subscriptionFailed == subscriptionFailed;

  @override
  int get hashCode =>
      Object.hash(trafficBlocked, startFailed, revoked, subscriptionFailed);

  @override
  String toString() =>
      'NotificationPrefs(trafficBlocked: $trafficBlocked, '
      'startFailed: $startFailed, revoked: $revoked, '
      'subscriptionFailed: $subscriptionFailed)';
}
