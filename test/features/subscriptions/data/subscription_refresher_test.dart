import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/core/models/stored_subscription/stored_subscription.dart';
import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/subscriptions/data/subscription_factory.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_parser_service.dart';
import 'package:slipstream/features/subscriptions/data/subscription_refresher.dart';

import 'subscription_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 22, 12);
  final before = DateTime(2026, 10, 21, 12);

  StoredSubscription stored({String? url = 'https://example.com/sub'}) =>
      StoredSubscription(
        subscription: Subscription(
          id: 'sub',
          url: url,
          name: 'Nebula',
          lastUpdatedAt: before,
          lastAttemptAt: before,
          lastError: 'old failure',
        ),
        servers: [server('old:443:uuid:#0')],
      );

  SubscriptionRefresher refresherWith(FakeParser parser) =>
      SubscriptionRefresher(parser, SubscriptionFactory(), now: () => now);

  test('success replaces servers and metadata and clears the error', () async {
    final parser = FakeParser(
      (_) async => Success(
        ParsedSubscription(
          servers: [server('new:443:uuid:#0'), server('new:443:uuid:#1')],
          updateIntervalHours: 6,
        ),
      ),
    );

    final result = await refresherWith(parser).refresh(stored());

    expect(parser.inputs, ['https://example.com/sub']);
    expect(result.servers.map((s) => s.id), [
      'new:443:uuid:#0',
      'new:443:uuid:#1',
    ]);
    expect(result.servers.every((s) => s.subscriptionId == 'sub'), isTrue);
    expect(result.subscription.updateIntervalHours, 6);
    expect(result.subscription.lastUpdatedAt, now);
    expect(result.subscription.lastAttemptAt, now);
    expect(result.subscription.lastError, isNull);
    expect(result.subscription.name, 'Nebula');
  });

  test('failure keeps the servers and records the attempt', () async {
    final parser = FakeParser((_) async => const Failure('HTTP error: 502'));

    final result = await refresherWith(parser).refresh(stored());

    expect(result.servers.map((s) => s.id), ['old:443:uuid:#0']);
    expect(result.subscription.lastUpdatedAt, before);
    expect(result.subscription.lastAttemptAt, now);
    expect(result.subscription.lastError, 'HTTP error: 502');
  });

  test('a subscription without a URL is returned untouched', () async {
    final parser = FakeParser((_) async => throw StateError('no fetch'));
    final manual = stored(url: null);

    final result = await refresherWith(parser).refresh(manual);

    expect(result, manual);
    expect(parser.inputs, isEmpty);
  });
}

VpnServer server(String id) => VpnServer(
  id: id,
  subscriptionId: 'whatever',
  countryCode: 'NL',
  title: id,
  configJson: '{}',
);
