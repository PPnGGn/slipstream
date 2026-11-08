import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/language/cubit/language_cubit.dart';
import 'package:slipstream/features/language/data/app_language.dart';
import 'package:slipstream/features/language/data/language_store.dart';
import 'package:slipstream/features/native_prefs/data/native_prefs_sink.dart';
import 'package:slipstream/features/native_prefs/presentation/native_prefs_runner.dart';
import 'package:slipstream/features/notifications/cubit/notifications_cubit.dart';
import 'package:slipstream/features/notifications/data/notifications_store.dart';
import 'package:talker_flutter/talker_flutter.dart';

class _FakeSink implements NativePrefsSink {
  final languages = <String>[];
  final alerts = <(bool, bool)>[];
  Object? failWith;

  @override
  Future<void> saveLanguage(String code) async {
    final error = failWith;
    if (error != null) throw error;
    languages.add(code);
  }

  @override
  Future<void> saveAlerts({
    required bool trafficBlocked,
    required bool startFailed,
  }) async {
    final error = failWith;
    if (error != null) throw error;
    alerts.add((trafficBlocked, startFailed));
  }

  @override
  Future<bool> notificationsAllowed() async => true;

  @override
  Future<void> openNotificationSettings() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(NativePrefsRunner, LanguageCubit, NotificationsCubit, _FakeSink)>
  build([Map<String, Object> stored = const {}]) async {
    SharedPreferences.setMockInitialValues(stored);
    final prefs = await SharedPreferences.getInstance();
    final language = LanguageCubit(store: LanguageStore(prefs));
    final notifications = NotificationsCubit(store: NotificationsStore(prefs));
    final sink = _FakeSink();
    return (
      NativePrefsRunner(sink, language, notifications, Talker()),
      language,
      notifications,
      sink,
    );
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('tells Kotlin the current language at start', () async {
    final (runner, _, _, sink) = await build({'app_language': 'ru'});
    runner.init();
    await settle();
    expect(sink.languages, ['ru']);
  });

  test('a fresh install sends "system", the phone decides', () async {
    final (runner, _, _, sink) = await build();
    runner.init();
    await settle();
    expect(sink.languages, ['system']);
  });

  test('sends every change of the language', () async {
    final (runner, language, _, sink) = await build();
    runner.init();
    await language.setLanguage(AppLanguage.fa);
    await language.setLanguage(AppLanguage.en);
    await settle();
    expect(sink.languages, ['system', 'fa', 'en']);
  });

  test('sends the alert switches at start and after each change', () async {
    final (runner, _, notifications, sink) = await build({
      'notify_start_failed': false,
    });
    runner.init();
    await settle();
    expect(sink.alerts, [(true, false)]);

    await notifications.setTrafficBlocked(enabled: false);
    await notifications.setStartFailed(enabled: true);
    await settle();
    expect(sink.alerts, [(true, false), (false, false), (false, true)]);
  });

  test('a failing bridge does not break the app', () async {
    final (runner, language, _, sink) = await build();
    sink.failWith = StateError('no bridge');
    runner.init();
    await language.setLanguage(AppLanguage.zh);
    await settle();
    expect(sink.languages, isEmpty);
    expect(sink.alerts, isEmpty);

    // It recovers: the next change goes through.
    sink.failWith = null;
    await language.setLanguage(AppLanguage.ru);
    await settle();
    expect(sink.languages, ['ru']);
  });

  test('init twice does not send twice', () async {
    final (runner, _, _, sink) = await build();
    runner.init();
    runner.init();
    await settle();
    expect(sink.languages, ['system']);
    expect(sink.alerts, hasLength(1));
  });
}
