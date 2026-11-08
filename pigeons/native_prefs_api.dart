import 'package:pigeon/pigeon.dart';

/// The settings that Kotlin needs without Flutter: the VPN service and the
/// quick settings tile run while the app is closed. Android only; every field
/// is nullable (null means "leave as it is"), so a message carries only what
/// changed.
class NativePrefsMessage {
  /// The language code the user picked ('en', 'ru', 'zh', 'fa'), or 'system'
  /// to follow the phone.
  String? language;

  /// Show the "traffic blocked" alert (the kill switch holds the traffic).
  bool? alertTrafficBlocked;

  /// Show the "could not start" alert (a start without the app failed).
  bool? alertStartFailed;
}

@HostApi()
abstract class NativePrefsApi {
  void save(NativePrefsMessage prefs);

  /// Whether Android lets the app show notifications at all.
  bool notificationsAllowed();

  /// Opens the system's notification settings of the app.
  void openNotificationSettings();
}
