import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/native_prefs/data/native_prefs_sink.dart';
import 'package:slipstream/features/notifications/cubit/notification_access_cubit.dart';
import 'package:slipstream/features/notifications/cubit/notifications_cubit.dart';
import 'package:slipstream/features/notifications/data/notification_prefs.dart';
import 'package:slipstream/features/notifications/data/notification_support.dart';
import 'package:slipstream/features/notifications/data/notifications_store.dart';
import 'package:slipstream/features/notifications/ui/notifications_labels.dart';
import 'package:slipstream/l10n/gen/app_localizations.dart';

import '../../helpers/l10n.dart';

class _FakeAccess implements NativePrefsSink {
  bool allowed = true;
  int opened = 0;
  Object? failWith;

  @override
  Future<bool> notificationsAllowed() async {
    final error = failWith;
    if (error != null) throw error;
    return allowed;
  }

  @override
  Future<void> openNotificationSettings() async => opened++;

  @override
  Future<void> saveLanguage(String code) async {}

  @override
  Future<void> saveAlerts({
    required bool trafficBlocked,
    required bool startFailed,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<NotificationsStore> storeWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return NotificationsStore(await SharedPreferences.getInstance());
  }

  test('only Android has these alerts', () {
    expect(isNotificationsSupported(TargetPlatform.android), isTrue);
    expect(isNotificationsSupported(TargetPlatform.iOS), isFalse);
    expect(isNotificationsSupported(TargetPlatform.windows), isFalse);
  });

  group('NotificationsStore', () {
    test('a fresh install has both alerts on', () async {
      final prefs = (await storeWith({})).load();
      expect(prefs.trafficBlocked, isTrue);
      expect(prefs.startFailed, isTrue);
    });

    test('save round-trips under the documented keys', () async {
      final store = await storeWith({});
      await store.save(
        const NotificationPrefs(trafficBlocked: false, startFailed: true),
      );
      expect(
        store.load(),
        const NotificationPrefs(trafficBlocked: false, startFailed: true),
      );
      final raw = await SharedPreferences.getInstance();
      expect(raw.getBool('notify_traffic_blocked'), isFalse);
      expect(raw.getBool('notify_start_failed'), isTrue);
    });
  });

  group('NotificationsCubit', () {
    test('starts from the store', () async {
      final cubit = NotificationsCubit(
        store: await storeWith({'notify_start_failed': false}),
      );
      expect(cubit.state.trafficBlocked, isTrue);
      expect(cubit.state.startFailed, isFalse);
    });

    test('each switch changes only its own alert, and is stored', () async {
      final store = await storeWith({});
      final cubit = NotificationsCubit(store: store);

      await cubit.setTrafficBlocked(enabled: false);
      expect(
        cubit.state,
        const NotificationPrefs(trafficBlocked: false, startFailed: true),
      );
      await cubit.setStartFailed(enabled: false);
      expect(
        cubit.state,
        const NotificationPrefs(trafficBlocked: false, startFailed: false),
      );
      expect(
        store.load(),
        const NotificationPrefs(trafficBlocked: false, startFailed: false),
      );
    });

    test('a call that changes nothing emits nothing', () async {
      final cubit = NotificationsCubit(store: await storeWith({}));
      final emitted = <NotificationPrefs>[];
      final sub = cubit.stream.listen(emitted.add);
      await cubit.setTrafficBlocked(enabled: true);
      await Future<void>.delayed(Duration.zero);
      expect(emitted, isEmpty);
      await sub.cancel();
    });
  });

  group('NotificationAccessCubit', () {
    test('asks the system and keeps the answer', () async {
      final access = _FakeAccess()..allowed = false;
      final cubit = NotificationAccessCubit(access);
      await cubit.refresh();
      expect(cubit.state, isFalse);

      access.allowed = true;
      await cubit.refresh();
      expect(cubit.state, isTrue);
    });

    test('assumes allowed until the system says otherwise', () {
      expect(NotificationAccessCubit(_FakeAccess()).state, isTrue);
    });

    test('a failing bridge leaves the answer as it was', () async {
      final access = _FakeAccess()..failWith = StateError('no bridge');
      final cubit = NotificationAccessCubit(access);
      await cubit.refresh();
      expect(cubit.state, isTrue);
    });

    test('opens the system settings of the app', () async {
      final access = _FakeAccess();
      await NotificationAccessCubit(access).openSettings();
      expect(access.opened, 1);
    });
  });

  group('notificationsSummary', () {
    String summary(
      NotificationPrefs prefs, {
      bool allowed = true,
      AppLocalizations? l10n,
    }) => notificationsSummary(l10n ?? l10nEn, prefs, allowed: allowed);

    test('both on', () {
      expect(summary(const NotificationPrefs()), 'All on');
    });

    test('one of two', () {
      expect(
        summary(const NotificationPrefs(trafficBlocked: false)),
        '1 of 2 on',
      );
      expect(summary(const NotificationPrefs(startFailed: false)), '1 of 2 on');
    });

    test('both off', () {
      expect(
        summary(
          const NotificationPrefs(trafficBlocked: false, startFailed: false),
        ),
        'Off',
      );
    });

    test('blocked in the system beats the switches', () {
      expect(
        summary(const NotificationPrefs(), allowed: false),
        'Blocked in system settings',
      );
    });

    test('speaks the chosen language', () {
      expect(summary(const NotificationPrefs(), l10n: l10nRu), 'Все включены');
    });
  });
}
