import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:slipstream/features/language/cubit/language_cubit.dart';
import 'package:slipstream/features/language/data/app_language.dart';
import 'package:slipstream/features/native_prefs/data/native_prefs_sink.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Keeps Kotlin in step with the app's language: the VPN notification and the
/// quick settings tile are built there, also while the app is closed, so they
/// need the user's choice on disk on their side. Sends it at start and after
/// every change; a failed send is only logged (the next change sends again).
@lazySingleton
class NativePrefsRunner {
  NativePrefsRunner(this._sink, this._language, this._talker);

  final NativePrefsSink _sink;
  final LanguageCubit _language;
  final Talker _talker;

  StreamSubscription<AppLanguage>? _subscription;

  void init() {
    if (_subscription != null) return;
    unawaited(_send(_language.state));
    _subscription = _language.stream.listen((language) {
      unawaited(_send(language));
    });
  }

  Future<void> _send(AppLanguage language) async {
    try {
      await _sink.saveLanguage(language.code);
    } on Object catch (e) {
      _talker.warning('NativePrefs: could not send the language: $e');
    }
  }
}
