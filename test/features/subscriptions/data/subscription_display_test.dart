import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/auto_update_interval.dart';
import 'package:slipstream/features/subscriptions/data/subscription_display.dart';

void main() {
  Subscription sub({
    String? url = 'https://example/sub',
    int? interval,
    String? lastError,
  }) => Subscription(
    id: 'nebula',
    url: url,
    name: 'Nebula',
    lastUpdatedAt: DateTime(2026, 7, 21, 14, 3),
    updateIntervalHours: interval,
    lastError: lastError,
  );

  String meta(
    Subscription subscription, {
    int serverCount = 7,
    bool refreshing = false,
    AutoUpdateInterval autoUpdate = AutoUpdateInterval.h12,
  }) => subscriptionMetaLine(
    subscription,
    serverCount: serverCount,
    refreshing: refreshing,
    autoUpdate: autoUpdate,
  );

  group('subscriptionMetaLine', () {
    test('counts servers and shows the last update and the interval', () {
      expect(meta(sub()), '7 SERVERS · UPD 21.07.2026 14:03 · EVERY 12H');
    });

    test('one server is singular', () {
      expect(
        meta(sub(), serverCount: 1),
        '1 SERVER · UPD 21.07.2026 14:03 · EVERY 12H',
      );
    });

    test('shows the provider interval when it overrides the setting', () {
      expect(
        meta(sub(interval: 6), autoUpdate: AutoUpdateInterval.h24),
        '7 SERVERS · UPD 21.07.2026 14:03 · EVERY 6H',
      );
    });

    test('says when auto-update is off', () {
      expect(
        meta(sub(interval: 6), autoUpdate: AutoUpdateInterval.off),
        '7 SERVERS · UPD 21.07.2026 14:03 · AUTO OFF',
      );
    });

    test('a subscription added without a URL is manual', () {
      expect(
        meta(sub(url: null), serverCount: 2),
        '2 SERVERS · UPD 21.07.2026 14:03 · MANUAL',
      );
    });

    test('flags a failed last attempt', () {
      expect(
        meta(sub(lastError: 'Timeout')),
        '7 SERVERS · UPD 21.07.2026 14:03 · EVERY 12H · UPDATE FAILED',
      );
    });

    test('while refreshing it says so instead', () {
      expect(meta(sub(), refreshing: true), 'UPDATING…');
    });
  });
}
