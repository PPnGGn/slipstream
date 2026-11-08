import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:slipstream/features/language/cubit/language_cubit.dart';
import 'package:slipstream/features/native_prefs/data/native_prefs_sink.dart';
import 'package:slipstream/features/notifications/cubit/notifications_cubit.dart';
import 'package:slipstream/features/notifications/data/notification_prefs.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Keeps Kotlin in step with the app's settings: the VPN notification, the
/// quick settings tile and the connection alerts are made there, also while the
/// app is closed, so they need the user's choices on disk on their side. Sends
/// them at start and after every change; a failed send is only logged (the next
/// change sends again).
@lazySingleton
class NativePrefsRunner {
  NativePrefsRunner(
    this._sink,
    this._language,
    this._notifications,
    this._talker,
  );

  final NativePrefsSink _sink;
  final LanguageCubit _language;
  final NotificationsCubit _notifications;
  final Talker _talker;

  final _subscriptions = <StreamSubscription<Object>>[];

  void init() {
    if (_subscriptions.isNotEmpty) return;
    unawaited(_sendLanguage(_language.state.code));
    unawaited(_sendAlerts(_notifications.state));
    _subscriptions.addAll([
      _language.stream.listen((language) => _sendLanguage(language.code)),
      _notifications.stream.listen(_sendAlerts),
    ]);
  }

  Future<void> _sendLanguage(String code) =>
      _guard('language', () => _sink.saveLanguage(code));

  Future<void> _sendAlerts(NotificationPrefs prefs) => _guard(
    'alerts',
    () => _sink.saveAlerts(
      trafficBlocked: prefs.trafficBlocked,
      startFailed: prefs.startFailed,
    ),
  );

  Future<void> _guard(String what, Future<void> Function() send) async {
    try {
      await send();
    } on Object catch (e) {
      _talker.warning('NativePrefs: could not send the $what: $e');
    }
  }
}
