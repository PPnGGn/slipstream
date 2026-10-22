import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/core/models/stored_subscription/stored_subscription.dart';
import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';
import 'package:slipstream/features/subscriptions/data/selected_server_store.dart';
import 'package:slipstream/features/subscriptions/data/subscription_factory.dart';
import 'package:slipstream/features/subscriptions/data/subscription_parser/subscription_parser_service.dart';
import 'package:slipstream/features/subscriptions/data/subscription_refresher.dart';

import '../data/subscription_fakes.dart';

VpnServer _server(String id, {String sub = 'a'}) => VpnServer(
  id: id,
  subscriptionId: sub,
  countryCode: 'NL',
  title: id,
  configJson: '{}',
);

StoredSubscription _stored(String id, List<String> serverIds) =>
    StoredSubscription(
      subscription: Subscription(
        id: id,
        url: 'https://example.com/$id',
        name: id,
        lastUpdatedAt: DateTime(2026, 10, 1),
      ),
      servers: [for (final s in serverIds) _server(s, sub: id)],
    );

Success<ParsedSubscription> _parsed(List<String> serverIds) => Success(
  ParsedSubscription(servers: [for (final s in serverIds) _server(s)]),
);

void main() {
  late InMemoryStorage storage;
  late SelectedServerStore selection;

  Future<SubscriptionsCubit> cubitWith(
    FakeParser parser, {
    List<StoredSubscription> initial = const [],
    (String, String)? selected,
  }) async {
    SharedPreferences.setMockInitialValues({});
    selection = SelectedServerStore(await SharedPreferences.getInstance());
    if (selected != null) await selection.save(selected.$1, selected.$2);
    storage = InMemoryStorage(initial);
    final factory = SubscriptionFactory();
    final cubit = SubscriptionsCubit(
      parser: parser,
      storage: storage,
      selectedServerStore: selection,
      factory: factory,
      refresher: SubscriptionRefresher(parser, factory),
      vpnServiceCubit: FakeVpnCubit(),
      talker: Talker(),
    );
    // Let the constructor's async load land.
    await Future<void>.delayed(Duration.zero);
    return cubit;
  }

  group('refreshSubscription', () {
    test('replaces the subscription and saves it', () async {
      final cubit = await cubitWith(
        FakeParser((_) async => _parsed(['x:1:u:#0', 'x:2:u:#1'])),
        initial: [
          _stored('a', ['old:1:u:#0']),
        ],
      );

      await cubit.refreshSubscription('a');

      final refreshed = cubit.state.subscriptions.single;
      expect(refreshed.servers.map((s) => s.id), ['x:1:u:#0', 'x:2:u:#1']);
      expect(refreshed.subscription.lastError, isNull);
      expect(storage.items['a']!.servers, hasLength(2));
      expect(cubit.state.refreshingIds, isEmpty);
    });

    test('writes the result to the right entry when the list changed '
        'during the fetch', () async {
      final gate = Completer<Result<ParsedSubscription>>();
      final cubit = await cubitWith(
        FakeParser((_) => gate.future),
        initial: [
          _stored('a', ['a:1:u:#0']),
          _stored('b', ['b:1:u:#0']),
        ],
      );

      final refresh = cubit.refreshSubscription('b');
      await cubit.removeSubscription('a');
      gate.complete(_parsed(['b:9:u:#0']));
      await refresh;

      expect(cubit.state.subscriptions, hasLength(1));
      expect(cubit.state.subscriptions.single.subscription.id, 'b');
      expect(cubit.state.subscriptions.single.servers.single.id, 'b:9:u:#0');
    });

    test(
      'drops the result when the subscription was deleted meanwhile',
      () async {
        final gate = Completer<Result<ParsedSubscription>>();
        final cubit = await cubitWith(
          FakeParser((_) => gate.future),
          initial: [
            _stored('a', ['a:1:u:#0']),
          ],
        );

        final refresh = cubit.refreshSubscription('a');
        await cubit.removeSubscription('a');
        gate.complete(_parsed(['a:1:u:#0']));
        await refresh;

        expect(cubit.state.subscriptions, isEmpty);
        expect(storage.items, isEmpty);
        expect(cubit.state.refreshingIds, isEmpty);
      },
    );

    test('a second refresh of the same subscription is ignored while the '
        'first runs', () async {
      final gate = Completer<Result<ParsedSubscription>>();
      final parser = FakeParser((_) => gate.future);
      final cubit = await cubitWith(
        parser,
        initial: [
          _stored('a', ['a:1:u:#0']),
        ],
      );

      final first = cubit.refreshSubscription('a');
      await cubit.refreshSubscription('a');
      gate.complete(_parsed(['a:1:u:#0']));
      await first;

      expect(parser.inputs, hasLength(1));
    });

    test('a failure keeps the servers and records the error', () async {
      final cubit = await cubitWith(
        FakeParser((_) async => const Failure('HTTP error: 502')),
        initial: [
          _stored('a', ['a:1:u:#0']),
        ],
      );

      await cubit.refreshSubscription('a');

      final sub = cubit.state.subscriptions.single;
      expect(sub.servers.single.id, 'a:1:u:#0');
      expect(sub.subscription.lastError, 'HTTP error: 502');
      expect(storage.items['a']!.subscription.lastError, 'HTTP error: 502');
      expect(cubit.state.refreshingIds, isEmpty);
    });

    test('keeps the selected server when the provider moved it', () async {
      final cubit = await cubitWith(
        FakeParser((_) async => _parsed(['new:1:u:#0', 'sel:1:u:#1'])),
        initial: [
          _stored('a', ['sel:1:u:#0']),
        ],
        selected: ('a', 'sel:1:u:#0'),
      );

      await cubit.refreshSubscription('a');

      expect(cubit.state.selectedServerId, 'sel:1:u:#1');
      expect(cubit.state.selectedServer?.id, 'sel:1:u:#1');
      expect(selection.load(), ('a', 'sel:1:u:#1'));
    });

    test('leaves the selection alone when the server is gone', () async {
      final cubit = await cubitWith(
        FakeParser((_) async => _parsed(['other:1:u:#0'])),
        initial: [
          _stored('a', ['sel:1:u:#0']),
        ],
        selected: ('a', 'sel:1:u:#0'),
      );

      await cubit.refreshSubscription('a');

      expect(cubit.state.selectedServerId, 'sel:1:u:#0');
      expect(selection.load(), ('a', 'sel:1:u:#0'));
    });
  });

  group('reloadFromStorage', () {
    test(
      'picks up what the background job saved, keeping the list order',
      () async {
        final cubit = await cubitWith(
          FakeParser((_) async => throw StateError('no fetch')),
          initial: [
            _stored('a', ['a:1:u:#0']),
            _stored('b', ['b:1:u:#0']),
          ],
        );
        await storage.save(_stored('a', ['a:2:u:#0', 'a:3:u:#1']));

        await cubit.reloadFromStorage();

        expect(cubit.state.subscriptions.map((s) => s.subscription.id), [
          'a',
          'b',
        ]);
        expect(cubit.state.subscriptions.first.servers, hasLength(2));
      },
    );

    test('follows a selected server whose id shifted', () async {
      final cubit = await cubitWith(
        FakeParser((_) async => throw StateError('no fetch')),
        initial: [
          _stored('a', ['sel:1:u:#0']),
        ],
        selected: ('a', 'sel:1:u:#0'),
      );
      await storage.save(_stored('a', ['new:1:u:#0', 'sel:1:u:#1']));

      await cubit.reloadFromStorage();

      expect(cubit.state.selectedServerId, 'sel:1:u:#1');
      expect(selection.load(), ('a', 'sel:1:u:#1'));
    });
  });
}
