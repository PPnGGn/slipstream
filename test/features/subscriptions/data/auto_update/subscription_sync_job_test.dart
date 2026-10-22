import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/core/models/stored_subscription/stored_subscription.dart';
import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/auto_update_interval.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/subscription_sync_job.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/subscription_update_settings_store.dart';
import 'package:slipstream/features/subscriptions/data/subscription_factory.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_parser_service.dart';
import 'package:slipstream/features/subscriptions/data/subscription_refresher.dart';

import '../subscription_fakes.dart';

final _now = DateTime(2026, 10, 22, 12);

StoredSubscription _stored(String id, {required Duration age, String? url}) =>
    StoredSubscription(
      subscription: Subscription(
        id: id,
        url: url ?? 'https://example.com/$id',
        name: id,
        lastUpdatedAt: _now.subtract(age),
      ),
      servers: const [],
    );

Success<ParsedSubscription> _ok() => Success(
  ParsedSubscription(
    servers: [
      const VpnServer(
        id: 'h:443:u:#0',
        subscriptionId: 'x',
        countryCode: 'NL',
        title: 'NL',
        configJson: '{}',
      ),
    ],
  ),
);

void main() {
  Future<SubscriptionSyncJob> jobWith(
    InMemoryStorage storage,
    FakeParser parser, {
    AutoUpdateInterval interval = AutoUpdateInterval.h12,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SubscriptionUpdateSettingsStore(
      await SharedPreferences.getInstance(),
    );
    await settings.saveInterval(interval);
    return SubscriptionSyncJob(
      storage,
      SubscriptionRefresher(parser, SubscriptionFactory(), now: () => _now),
      settings,
      Talker(),
      now: () => _now,
    );
  }

  test('refreshes and saves only the subscriptions that are due', () async {
    final storage = InMemoryStorage([
      _stored('stale', age: const Duration(hours: 13)),
      _stored('fresh', age: const Duration(hours: 1)),
    ]);
    final parser = FakeParser((_) async => _ok());

    final ok = await (await jobWith(storage, parser)).run();

    expect(ok, isTrue);
    expect(parser.inputs, ['https://example.com/stale']);
    expect(storage.saved, ['stale']);
    expect(storage.items['stale']!.subscription.lastUpdatedAt, _now);
    expect(storage.items['stale']!.servers, hasLength(1));
  });

  test('does nothing when auto-update is off', () async {
    final storage = InMemoryStorage([
      _stored('stale', age: const Duration(days: 30)),
    ]);
    final parser = FakeParser((_) async => _ok());

    final ok = await (await jobWith(
      storage,
      parser,
      interval: AutoUpdateInterval.off,
    )).run();

    expect(ok, isTrue);
    expect(parser.inputs, isEmpty);
    expect(storage.saved, isEmpty);
  });

  test('saves a failure so the schedule backs off, and reports it', () async {
    final storage = InMemoryStorage([
      _stored('stale', age: const Duration(hours: 13)),
    ]);
    final parser = FakeParser((_) async => const Failure('HTTP error: 502'));

    final ok = await (await jobWith(storage, parser)).run();

    expect(ok, isFalse);
    final sub = storage.items['stale']!.subscription;
    expect(sub.lastError, 'HTTP error: 502');
    expect(sub.lastAttemptAt, _now);
  });

  test('does not bring back a subscription deleted during the fetch', () async {
    final storage = InMemoryStorage([
      _stored('stale', age: const Duration(hours: 13)),
    ]);
    final parser = FakeParser((_) async {
      await storage.delete('stale');
      return _ok();
    });

    await (await jobWith(storage, parser)).run();

    expect(storage.items, isEmpty);
    expect(storage.saved, isEmpty);
  });

  test('one failure does not stop the others', () async {
    final storage = InMemoryStorage([
      _stored('broken', age: const Duration(hours: 13)),
      _stored('works', age: const Duration(hours: 13)),
    ]);
    final parser = FakeParser(
      (input) async =>
          input.endsWith('broken') ? const Failure('Timeout') : _ok(),
    );

    final ok = await (await jobWith(storage, parser)).run();

    expect(ok, isFalse);
    expect(storage.items['works']!.subscription.lastError, isNull);
    expect(storage.items['works']!.servers, hasLength(1));
  });
}
