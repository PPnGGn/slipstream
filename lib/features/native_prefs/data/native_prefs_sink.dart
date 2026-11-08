import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:slipstream/features/native_prefs/data/native_prefs_api.g.dart';

/// Where the settings that Kotlin needs go. An interface so the runner can be
/// tested without a platform channel.
abstract interface class NativePrefsSink {
  /// [code] is a language code of the app ('en', 'ru', 'zh', 'fa') or
  /// 'system' for "follow the phone".
  Future<void> saveLanguage(String code);
}

/// The Pigeon bridge to NativePrefsStore (Android). Other platforms have no
/// native service that speaks the user's language, so nothing is sent.
@LazySingleton(as: NativePrefsSink)
class PlatformNativePrefsSink implements NativePrefsSink {
  final _api = NativePrefsApi();

  @override
  Future<void> saveLanguage(String code) async {
    if (!Platform.isAndroid) return;
    await _api.save(NativePrefsMessage(language: code));
  }
}
