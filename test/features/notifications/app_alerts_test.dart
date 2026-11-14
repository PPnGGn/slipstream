import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/notifications/data/alerts_api.g.dart';
import 'package:slipstream/features/notifications/data/app_alerts.dart';
import 'package:talker_flutter/talker_flutter.dart';

class _FakeApi extends AppAlertsApi {
  final shown = <AppAlertMessage>[];
  final cancelled = <(AppAlertKind, String)>[];
  Object? failWith;

  @override
  Future<void> show(AppAlertMessage message) async {
    final error = failWith;
    if (error != null) throw error;
    shown.add(message);
  }

  @override
  Future<void> cancel(AppAlertKind kind, String subscriptionName) async {
    final error = failWith;
    if (error != null) throw error;
    cancelled.add((kind, subscriptionName));
  }
}

void main() {
  PlatformAppAlerts alerts(_FakeApi api, {required bool android}) =>
      PlatformAppAlerts.withApi(api, Talker(), isAndroid: android);

  group('on Android', () {
    test('show passes the kind, the name and the number on', () async {
      final api = _FakeApi();

      await alerts(api, android: true).show(
        AppAlertKind.subscriptionExpiring,
        subscriptionName: 'Liberty VPN',
        number: 2,
      );

      expect(api.shown, hasLength(1));
      expect(api.shown.single.kind, AppAlertKind.subscriptionExpiring);
      expect(api.shown.single.subscriptionName, 'Liberty VPN');
      expect(api.shown.single.number, 2);
    });

    test('a kind with no number sends none', () async {
      final api = _FakeApi();

      await alerts(
        api,
        android: true,
      ).show(AppAlertKind.subscriptionFailed, subscriptionName: 'DuckVPN');

      expect(api.shown.single.number, isNull);
    });

    test('cancel passes the kind and the name on', () async {
      final api = _FakeApi();

      await alerts(
        api,
        android: true,
      ).cancel(AppAlertKind.trafficLow, 'DuckVPN');

      expect(api.cancelled, [(AppAlertKind.trafficLow, 'DuckVPN')]);
    });

    // A failed alert must never break what raised it (a background refresh that
    // already did its work, a subscription update).
    test('a bridge that is missing or fails is not an error', () async {
      for (final error in <Object>[
        MissingPluginException('no bridge'),
        PlatformException(code: 'x'),
      ]) {
        final api = _FakeApi()..failWith = error;
        final alerts0 = alerts(api, android: true);

        await alerts0.show(
          AppAlertKind.trafficExhausted,
          subscriptionName: 'DuckVPN',
        );
        await alerts0.cancel(AppAlertKind.trafficExhausted, 'DuckVPN');
      }
    });
  });

  group('elsewhere', () {
    test('nothing is sent: only Android has these alerts', () async {
      final api = _FakeApi();
      final other = alerts(api, android: false);

      await other.show(
        AppAlertKind.subscriptionExpired,
        subscriptionName: 'DuckVPN',
      );
      await other.cancel(AppAlertKind.subscriptionExpired, 'DuckVPN');

      expect(api.shown, isEmpty);
      expect(api.cancelled, isEmpty);
    });
  });
}
