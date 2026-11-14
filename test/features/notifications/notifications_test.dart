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
    required bool revoked,
    required bool tunnelLost,
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
    test('a fresh install has every alert on', () async {
      final prefs = (await storeWith({})).load();
      expect(prefs.trafficBlocked, isTrue);
      expect(prefs.startFailed, isTrue);
      expect(prefs.revoked, isTrue);
    });

    test('save round-trips under the documented keys', () async {
      final store = await storeWith({});
      await store.save(
        const NotificationPrefs(
          trafficBlocked: false,
          startFailed: true,
          revoked: false,
        ),
      );
      expect(
        store.load(),
        const NotificationPrefs(
          trafficBlocked: false,
          startFailed: true,
          revoked: false,
        ),
      );
      final raw = await SharedPreferences.getInstance();
      expect(raw.getBool('notify_traffic_blocked'), isFalse);
      expect(raw.getBool('notify_start_failed'), isTrue);
      expect(raw.getBool('notify_revoked'), isFalse);
    });

    test('the subscription alert has its own key and starts on', () async {
      final store = await storeWith({});
      expect(store.load().subscriptionFailed, isTrue);

      await store.save(const NotificationPrefs(subscriptionFailed: false));

      final raw = await SharedPreferences.getInstance();
      expect(raw.getBool('notify_subscription_failed'), isFalse);
      expect(store.load().subscriptionFailed, isFalse);
    });

    test('the lost tunnel alert has its own key and starts on', () async {
      final store = await storeWith({});
      expect(store.load().tunnelLost, isTrue);

      await store.save(const NotificationPrefs(tunnelLost: false));

      final raw = await SharedPreferences.getInstance();
      expect(raw.getBool('notify_tunnel_lost'), isFalse);
      expect(store.load().tunnelLost, isFalse);
    });

    test(
      'the expiry and traffic alert has its own key and starts on',
      () async {
        final store = await storeWith({});
        expect(store.load().subscriptionLimits, isTrue);

        await store.save(const NotificationPrefs(subscriptionLimits: false));

        final raw = await SharedPreferences.getInstance();
        expect(raw.getBool('notify_subscription_limits'), isFalse);
        expect(store.load().subscriptionLimits, isFalse);
      },
    );

    test('an install from before the alert existed reads it as on', () async {
      final prefs = (await storeWith({
        'notify_traffic_blocked': false,
        'notify_start_failed': false,
      })).load();
      expect(prefs.revoked, isTrue);
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
      await cubit.setRevoked(enabled: false);
      await cubit.setSubscriptionFailed(enabled: false);
      await cubit.setSubscriptionLimits(enabled: false);
      await cubit.setTunnelLost(enabled: false);
      const allOff = NotificationPrefs(
        tunnelLost: false,
        trafficBlocked: false,
        startFailed: false,
        revoked: false,
        subscriptionFailed: false,
        subscriptionLimits: false,
      );
      expect(cubit.state, allOff);
      expect(store.load(), allOff);
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

    test('all on', () {
      expect(summary(const NotificationPrefs()), 'All on');
    });

    test('some on counts them against all the alerts there are', () {
      expect(
        summary(const NotificationPrefs(trafficBlocked: false)),
        '5 of 6 on',
      );
      expect(summary(const NotificationPrefs(revoked: false)), '5 of 6 on');
      expect(
        summary(const NotificationPrefs(subscriptionFailed: false)),
        '5 of 6 on',
      );
      expect(
        summary(
          const NotificationPrefs(trafficBlocked: false, startFailed: false),
        ),
        '4 of 6 on',
      );
    });

    test('all off', () {
      expect(
        summary(
          const NotificationPrefs(
            trafficBlocked: false,
            startFailed: false,
            revoked: false,
            subscriptionFailed: false,
            subscriptionLimits: false,
            tunnelLost: false,
          ),
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
