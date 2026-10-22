import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/features/subscriptions/data/subscription_display.dart';

void main() {
  Subscription sub({String? url = 'https://example/sub', int? interval}) =>
      Subscription(
        id: 'nebula',
        url: url,
        name: 'Nebula',
        lastUpdatedAt: DateTime(2026, 7, 21, 14, 3),
        updateIntervalHours: interval,
      );

  group('subscriptionMetaLine', () {
    test('counts servers and shows the last update', () {
      expect(
        subscriptionMetaLine(sub(), serverCount: 7, refreshing: false),
        '7 SERVERS · UPD 21.07.2026 14:03',
      );
    });

    test('one server is singular', () {
      expect(
        subscriptionMetaLine(sub(), serverCount: 1, refreshing: false),
        '1 SERVER · UPD 21.07.2026 14:03',
      );
    });

    test('a provider update interval is appended', () {
      expect(
        subscriptionMetaLine(
          sub(interval: 12),
          serverCount: 7,
          refreshing: false,
        ),
        '7 SERVERS · UPD 21.07.2026 14:03 · EVERY 12H',
      );
    });

    test('a subscription added without a URL is manual', () {
      expect(
        subscriptionMetaLine(sub(url: null), serverCount: 2, refreshing: false),
        '2 SERVERS · UPD 21.07.2026 14:03 · MANUAL',
      );
    });

    test('while refreshing it says so instead', () {
      expect(
        subscriptionMetaLine(sub(), serverCount: 7, refreshing: true),
        'UPDATING…',
      );
    });
  });
}
