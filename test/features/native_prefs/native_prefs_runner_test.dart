import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/language/cubit/language_cubit.dart';
import 'package:slipstream/features/language/data/app_language.dart';
import 'package:slipstream/features/language/data/language_store.dart';
import 'package:slipstream/features/native_prefs/data/native_prefs_sink.dart';
import 'package:slipstream/features/native_prefs/presentation/native_prefs_runner.dart';
import 'package:talker_flutter/talker_flutter.dart';

class _FakeSink implements NativePrefsSink {
  final sent = <String>[];
  Object? failWith;

  @override
  Future<void> saveLanguage(String code) async {
    final error = failWith;
    if (error != null) throw error;
    sent.add(code);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(NativePrefsRunner, LanguageCubit, _FakeSink)> build([
    Map<String, Object> stored = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(stored);
    final cubit = LanguageCubit(
      store: LanguageStore(await SharedPreferences.getInstance()),
    );
    final sink = _FakeSink();
    return (NativePrefsRunner(sink, cubit, Talker()), cubit, sink);
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('tells Kotlin the current language at start', () async {
    final (runner, _, sink) = await build({'app_language': 'ru'});
    runner.init();
    await settle();
    expect(sink.sent, ['ru']);
  });

  test('a fresh install sends "system", the phone decides', () async {
    final (runner, _, sink) = await build();
    runner.init();
    await settle();
    expect(sink.sent, ['system']);
  });

  test('sends every change of the language', () async {
    final (runner, cubit, sink) = await build();
    runner.init();
    await cubit.setLanguage(AppLanguage.fa);
    await cubit.setLanguage(AppLanguage.en);
    await settle();
    expect(sink.sent, ['system', 'fa', 'en']);
  });

  test('a failing bridge does not break the app', () async {
    final (runner, cubit, sink) = await build();
    sink.failWith = StateError('no bridge');
    runner.init();
    await cubit.setLanguage(AppLanguage.zh);
    await settle();
    expect(sink.sent, isEmpty);

    // It recovers: the next change goes through.
    sink.failWith = null;
    await cubit.setLanguage(AppLanguage.ru);
    await settle();
    expect(sink.sent, ['ru']);
  });
}
