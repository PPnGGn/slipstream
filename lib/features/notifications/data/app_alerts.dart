import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/notifications/data/alerts_api.g.dart';
import 'package:talker_flutter/talker_flutter.dart';

export 'package:slipstream/features/notifications/data/alerts_api.g.dart'
    show AppAlertKind;

/// The alerts about subscriptions: the refresh failed, the time or the traffic
/// is running out. Dart decides when (the rules live where the subscription
/// is updated), this only hands the fact over; Kotlin makes the notification in
/// the language the user picked. An interface so those rules can be tested with
/// no platform channel.
///
/// Showing is best effort: a failure never reaches the caller, because what
/// called it (a refresh that already did its work) must not break for want of
/// a notification.
abstract interface class AppAlerts {
  /// [number] is the days left or the percent used, for the kinds that say one.
  Future<void> show(
    AppAlertKind kind, {
    required String subscriptionName,
    int? number,
  });

  /// Takes the alert of this kind and subscription away, when its cause is gone.
  Future<void> cancel(AppAlertKind kind, String subscriptionName);
}

/// The Pigeon bridge to AppAlerts.kt (Android). Other platforms have no such
/// alerts, so nothing is sent there.
@LazySingleton(as: AppAlerts)
class PlatformAppAlerts implements AppAlerts {
  PlatformAppAlerts(this._talker) : _api = AppAlertsApi(), _isAndroid = null;

  @visibleForTesting
  PlatformAppAlerts.withApi(this._api, this._talker, {required bool isAndroid})
    : _isAndroid = isAndroid;

  final AppAlertsApi _api;
  final Talker _talker;
  final bool? _isAndroid;

  bool get _android => _isAndroid ?? Platform.isAndroid;

  @override
  Future<void> show(
    AppAlertKind kind, {
    required String subscriptionName,
    int? number,
  }) => _guard(
    'show',
    () => _api.show(
      AppAlertMessage(
        kind: kind,
        subscriptionName: subscriptionName,
        number: number,
      ),
    ),
  );

  @override
  Future<void> cancel(AppAlertKind kind, String subscriptionName) =>
      _guard('cancel', () => _api.cancel(kind, subscriptionName));

  Future<void> _guard(String what, Future<void> Function() call) async {
    if (!_android) return;
    try {
      await call();
    } on Object catch (e) {
      // The name of the subscription is not logged: it can be a provider's
      // private label.
      _talker.warning('AppAlerts: could not $what an alert: $e');
    }
  }
}
