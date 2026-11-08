import 'package:pigeon/pigeon.dart';

/// The settings that Kotlin needs without Flutter: the VPN service and the
/// quick settings tile run while the app is closed. Android only; new fields
/// are nullable (null means "leave as it is").
class NativePrefsMessage {
  /// The language code the user picked ('en', 'ru', 'zh', 'fa'), or 'system'
  /// to follow the phone.
  String? language;
}

@HostApi()
abstract class NativePrefsApi {
  void save(NativePrefsMessage prefs);
}
