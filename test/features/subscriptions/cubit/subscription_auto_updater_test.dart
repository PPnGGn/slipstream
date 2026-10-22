import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/core/models/stored_subscription/stored_subscription.dart';
import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/subscriptions/cubit/subscription_auto_updater.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/auto_update_interval.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/subscription_update_settings_store.dart';
import 'package:slipstream/features/subscriptions/data/selected_server_store.dart';
import 'package:slipstream/features/subscriptions/data/subscription_factory.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_parser_service.dart';
import 'package:slipstream/features/subscriptions/data/subscription_refresher.dart';

import '../data/subscription_fakes.dart';

final _now = DateTime(2026, 10, 22, 12);

const _server = VpnServer(
  id: 'h:443:u:#0',
  subscriptionId: 'x',
  countryCode: 'NL',
  title: 'NL',
  configJson: '{}',
);

StoredSubscription _stored(
  String id, {
  Duration age = const Duration(hours: 1),
  String? url = 'https://example.com/sub',
  String? lastError,
}) => StoredSubscription(
  subscription: Subscription(
    id: id,
    url: url,
    name: id,
    lastUpdatedAt: _now.subtract(age),
    lastAttemptAt: lastError == null ? null : _now,
    lastError: lastError,
  ),
  servers: const [_server],
);

/// Lets the cubit's async load, zero-delay timers and refreshes land.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeParser parser;
  late FakeVpnCubit vpn;
  late FakeBackgroundSync background;
  late SubscriptionUpdateSettingsStore settings;
  late SubscriptionAutoUpdater updater;

  Future<void> start(
    List<StoredSubscription> initial, {
    AutoUpdateInterval interval = AutoUpdateInterval.h12,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    settings = SubscriptionUpdateSettingsStore(prefs);
    await settings.saveInterval(interval);
    parser = FakeParser(
      (_) async => Success(ParsedSubscription(servers: const [_server])),
    );
    vpn = FakeVpnCubit();
    background = FakeBackgroundSync();
    final factory = SubscriptionFactory();
    final subscriptions = SubscriptionsCubit(
      parser: parser,
      storage: InMemoryStorage(initial),
      selectedServerStore: SelectedServerStore(prefs),
      factory: factory,
      refresher: SubscriptionRefresher(parser, factory, now: () => _now),
      vpnServiceCubit: vpn,
      talker: Talker(),
    );
    updater = SubscriptionAutoUpdater(
      subscriptions,
      settings,
      vpn,
      background,
      Talker(),
      now: () => _now,
    )..init();
    await _settle();
  }

  tearDown(() => updater.dispose());

  test('refreshes a due subscription once the list has loaded', () async {
    await start([_stored('a', age: const Duration(hours: 13))]);

    expect(parser.inputs, ['https://example.com/sub']);
  });

  test('leaves a fresh subscription alone', () async {
    await start([_stored('a')]);

    expect(parser.inputs, isEmpty);
  });

  test(
    'a VPN connection retries a subscription whose last attempt failed',
    () async {
      await start([_stored('a', lastError: 'Connection reset by peer')]);
      expect(parser.inputs, isEmpty, reason: 'still backing off');

      vpn.push(const VpnState.connecting());
      vpn.push(VpnState.connected(_server, connectedAt: _now));
      await _settle();

      expect(parser.inputs, ['https://example.com/sub']);
    },
  );

  test('staying connected does not retry again', () async {
    await start([_stored('a', lastError: 'Connection reset by peer')]);
    vpn.push(VpnState.connected(_server, connectedAt: _now));
    await _settle();

    vpn.push(VpnState.connected(_server, connectedAt: _now));
    await _settle();

    expect(parser.inputs, hasLength(1));
  });

  test('turns the background job on for URL subscriptions and off with the '
      'setting', () async {
    await start([_stored('a')]);
    expect(background.calls, [true]);

    await settings.saveInterval(AutoUpdateInterval.off);
    updater.reschedule();
    await _settle();

    expect(background.calls, [true, false]);
  });

  test('keeps the background job off without URL subscriptions', () async {
    await start([_stored('a', url: null)]);

    expect(background.calls, [false]);
  });
}
