import 'package:pigeon/pigeon.dart';

/// The alerts the app itself raises about subscriptions, which the VPN service
/// does not know about (those are ConnectionAlert in Kotlin). Android only,
/// like NativePrefsApi. Dart decides when to alert and passes only the kind and
/// the facts; the texts are Kotlin's, in the language the user picked, because
/// the headless engine of the background job has no UI to localize them.
enum AppAlertKind {
  /// The refresh of a subscription failed (from the background job).
  subscriptionFailed,

  /// The subscription runs out in a few days; `number` is the days left.
  subscriptionExpiring,

  /// The subscription's time is up.
  subscriptionExpired,

  /// Most of the traffic is used; `number` is the percent.
  trafficLow,

  /// All the traffic is used.
  trafficExhausted,
}

class AppAlertMessage {
  AppAlertMessage({
    required this.kind,
    required this.subscriptionName,
    this.number,
  });

  AppAlertKind kind;

  /// Shown in the text. One alert per kind and name: the same pair replaces its
  /// earlier alert instead of stacking.
  String subscriptionName;

  /// Days or percent, for the kinds that say a number.
  int? number;
}

@HostApi()
abstract class AppAlertsApi {
  /// Posts the alert. Quiet when Android blocks the app's notifications.
  void show(AppAlertMessage message);

  /// Takes the alert of this kind and subscription away (the cause is gone:
  /// the subscription was renewed or deleted).
  void cancel(AppAlertKind kind, String subscriptionName);
}
