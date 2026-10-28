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
    lastUpdatedAt: DateTime(2026, 10, 29, 1, 11),
    updateIntervalHours: interval,
    lastError: lastError,
  );

  SubscriptionMeta meta(
    Subscription subscription, {
    int serverCount = 40,
    bool refreshing = false,
    AutoUpdateInterval autoUpdate = AutoUpdateInterval.h12,
  }) => subscriptionMeta(
    subscription,
    serverCount: serverCount,
    refreshing: refreshing,
    autoUpdate: autoUpdate,
  );

  group('subscriptionMeta', () {
    test('has the short date, the server count and the interval', () {
      final m = meta(sub());

      expect(m.updated, '29.10.26, 01:11');
      expect(m.serverCount, 40);
      expect(m.interval, '12h');
      expect(m.failed, isFalse);
      expect(m.refreshing, isFalse);
    });

    test('shows the provider interval when it overrides the setting', () {
      expect(
        meta(sub(interval: 6), autoUpdate: AutoUpdateInterval.h24).interval,
        '6h',
      );
    });

    test('says when auto-update is off', () {
      expect(
        meta(sub(interval: 6), autoUpdate: AutoUpdateInterval.off).interval,
        'off',
      );
    });

    test('a subscription added without a URL has no interval', () {
      expect(meta(sub(url: null)).interval, isNull);
    });

    test('flags a failed last attempt', () {
      expect(meta(sub(lastError: 'Timeout')).failed, isTrue);
    });

    test('carries the refreshing flag', () {
      expect(meta(sub(), refreshing: true).refreshing, isTrue);
    });
  });
}
