import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/stored_subscription/stored_subscription.dart';
import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/subscriptions/data/subscription_storage/file_subscription_storage.dart';

void main() {
  late Directory tempDir;
  late FileSubscriptionStorage storage;

  StoredSubscription buildSubscription(String id, {String name = 'Test'}) {
    return StoredSubscription(
      subscription: Subscription(
        id: id,
        url: 'https://example.com/$id',
        name: name,
        lastUpdatedAt: DateTime.utc(2026, 7, 20, 12),
      ),
      servers: [
        VpnServer(
          id: '$id-server-1',
          subscriptionId: id,
          countryCode: 'NL',
          title: 'Amsterdam',
          configJson: 'vless://uuid@host:443',
        ),
      ],
    );
  }

  /// The directory where the storage actually keeps its files.
  Directory subscriptionsDir() =>
      Directory('${tempDir.path}${Platform.pathSeparator}subscriptions');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('storage_test');
    storage = FileSubscriptionStorage(tempDir, Talker());
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('loadAll', () {
    test('returns an empty list when nothing was saved', () async {
      final result = await storage.loadAll();

      expect(result, isEmpty);
    });

    test('skips a corrupted file but loads the rest', () async {
      await storage.save(buildSubscription('good'));
      final broken = File('${subscriptionsDir().path}/broken.json');
      await broken.writeAsString('{not valid json');

      final result = await storage.loadAll();

      expect(result, hasLength(1));
      expect(result.single.subscription.id, 'good');
    });

    test('skips a file written by a newer schema version', () async {
      await storage.save(buildSubscription('current'));
      final future = File('${subscriptionsDir().path}/future.json');
      await future.writeAsString('{"version": 999, "data": {}}');

      final result = await storage.loadAll();

      expect(result, hasLength(1));
      expect(result.single.subscription.id, 'current');
    });

    test('removes a leftover tmp file from an interrupted write', () async {
      await storage.save(buildSubscription('sub'));
      final tmp = File('${subscriptionsDir().path}/sub.json.tmp');
      await tmp.writeAsString('half-written garbage');

      final result = await storage.loadAll();

      expect(result, hasLength(1));
      expect(await tmp.exists(), isFalse);
    });
  });

  group('save', () {
    test('round-trips a subscription with its servers', () async {
      final original = buildSubscription('sub-1');

      await storage.save(original);
      final result = await storage.loadAll();

      expect(result.single, original);
    });

    test('replaces the subscription with the same id', () async {
      await storage.save(buildSubscription('sub-1', name: 'Old'));
      await storage.save(buildSubscription('sub-1', name: 'New'));

      final result = await storage.loadAll();

      expect(result, hasLength(1));
      expect(result.single.subscription.name, 'New');
    });

    test('stores subscriptions independently of each other', () async {
      await storage.save(buildSubscription('sub-1'));
      await storage.save(buildSubscription('sub-2'));

      final result = await storage.loadAll();

      expect(
        result.map((s) => s.subscription.id),
        unorderedEquals(['sub-1', 'sub-2']),
      );
    });

    test('throws on an id that could escape the storage directory', () async {
      final malicious = buildSubscription('../evil');

      expect(() => storage.save(malicious), throwsArgumentError);
    });
  });

  group('delete', () {
    test('removes only the requested subscription', () async {
      await storage.save(buildSubscription('keep'));
      await storage.save(buildSubscription('remove'));

      await storage.delete('remove');
      final result = await storage.loadAll();

      expect(result.single.subscription.id, 'keep');
    });

    test('does nothing for a missing id', () async {
      await expectLater(storage.delete('missing'), completes);
    });
  });
}
