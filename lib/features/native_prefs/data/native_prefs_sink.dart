import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:slipstream/features/native_prefs/data/native_prefs_api.g.dart';

/// Where the settings that Kotlin needs go, and what it can tell back. An
/// interface so the runner and the cubits can be tested without a platform
/// channel.
abstract interface class NativePrefsSink {
  /// [code] is a language code of the app ('en', 'ru', 'zh', 'fa') or
  /// 'system' for "follow the phone".
  Future<void> saveLanguage(String code);

  Future<void> saveAlerts({
    required bool trafficBlocked,
    required bool startFailed,
  });

  /// Whether Android lets the app show notifications at all.
  Future<bool> notificationsAllowed();

  /// Opens the system's notification settings of the app.
  Future<void> openNotificationSettings();
}

/// The Pigeon bridge to NativePrefsStore (Android). Other platforms have no
/// native service that speaks the user's language or shows alerts, so nothing
/// is sent, and notifications count as allowed.
@LazySingleton(as: NativePrefsSink)
class PlatformNativePrefsSink implements NativePrefsSink {
  final _api = NativePrefsApi();

  @override
  Future<void> saveLanguage(String code) async {
    if (!Platform.isAndroid) return;
    await _api.save(NativePrefsMessage(language: code));
  }

  @override
  Future<void> saveAlerts({
    required bool trafficBlocked,
    required bool startFailed,
  }) async {
    if (!Platform.isAndroid) return;
    await _api.save(
      NativePrefsMessage(
        alertTrafficBlocked: trafficBlocked,
        alertStartFailed: startFailed,
      ),
    );
  }

  @override
  Future<bool> notificationsAllowed() async {
    if (!Platform.isAndroid) return true;
    return _api.notificationsAllowed();
  }

  @override
  Future<void> openNotificationSettings() async {
    if (!Platform.isAndroid) return;
    await _api.openNotificationSettings();
  }
}
