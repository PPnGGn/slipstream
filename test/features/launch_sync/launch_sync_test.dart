import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/launch_sync/data/launch_sync.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';

void main() {
  const server = VpnServer(
    id: 's1',
    subscriptionId: 'sub',
    countryCode: 'NL',
    title: 'Amsterdam',
    configJson: '{}',
  );

  late StreamController<void> changes;
  late VpnState vpnState;
  late VpnServer? selected;
  late List<String> built;
  late List<VpnConfigMessage> saved;
  late LaunchSync sync;

  setUp(() {
    changes = StreamController<void>.broadcast(sync: true);
    vpnState = const VpnState.disconnected();
    selected = server;
    built = [];
    saved = [];
    sync = LaunchSync(
      changes: changes.stream,
      vpnState: () => vpnState,
      selectedServer: () => selected,
      build: (s) async {
        built.add(s.id);
        return VpnConfigMessage(
          configJson: '{"for":"${s.id}"}',
          serverId: s.id,
        );
      },
      save: (message) async => saved.add(message),
      debounce: const Duration(milliseconds: 400),
    );
  });

  tearDown(() async {
    await sync.dispose();
    await changes.close();
  });

  test('one change: the launch is saved after the debounce, not before', () {
    fakeAsync((async) {
      sync.start();
      changes.add(null);

      async.elapse(const Duration(milliseconds: 399));
      expect(saved, isEmpty);

      async.elapse(const Duration(milliseconds: 2));
      async.flushMicrotasks();
      expect(saved.map((m) => m.serverId), ['s1']);
    });
  });

  test('a burst of changes is one save', () {
    fakeAsync((async) {
      sync.start();
      for (var i = 0; i < 5; i++) {
        changes.add(null);
        async.elapse(const Duration(milliseconds: 100));
      }
      async.elapse(const Duration(milliseconds: 500));
      async.flushMicrotasks();

      expect(built, ['s1']);
      expect(saved, hasLength(1));
    });
  });

  test('nothing is built or saved while a session runs', () {
    fakeAsync((async) {
      vpnState = const VpnState.connecting();
      sync.start();
      changes.add(null);
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();

      expect(built, isEmpty);
      expect(saved, isEmpty);
    });
  });

  test('nothing without a selected server', () {
    fakeAsync((async) {
      selected = null;
      sync.start();
      changes.add(null);
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();

      expect(saved, isEmpty);
    });
  });

  test('a session that starts while the config is being built wins', () {
    // The user taps connect between "decided to save" and "saving": the start
    // writes the launch itself, and a late save must not land on top of it.
    fakeAsync((async) {
      final gate = Completer<void>();
      final slow = LaunchSync(
        changes: changes.stream,
        vpnState: () => vpnState,
        selectedServer: () => selected,
        build: (s) async {
          await gate.future;
          return VpnConfigMessage(configJson: '{}', serverId: s.id);
        },
        save: (message) async => saved.add(message),
        debounce: const Duration(milliseconds: 400),
      )..start();

      changes.add(null);
      async.elapse(const Duration(milliseconds: 500));
      vpnState = const VpnState.connecting();
      gate.complete();
      async.flushMicrotasks();

      expect(saved, isEmpty);
      slow.dispose();
    });
  });

  test('the server that was selected when the build ended is what is saved', () {
    // The selection moved during the build: the message is for the old one, so
    // it is dropped; the change that moved it schedules a new pass anyway.
    fakeAsync((async) {
      final gate = Completer<void>();
      final slow = LaunchSync(
        changes: changes.stream,
        vpnState: () => vpnState,
        selectedServer: () => selected,
        build: (s) async {
          await gate.future;
          return VpnConfigMessage(configJson: '{}', serverId: s.id);
        },
        save: (message) async => saved.add(message),
        debounce: const Duration(milliseconds: 400),
      )..start();

      changes.add(null);
      async.elapse(const Duration(milliseconds: 500));
      selected = const VpnServer(
        id: 's2',
        subscriptionId: 'sub',
        countryCode: 'DE',
        title: 'Berlin',
        configJson: '{}',
      );
      gate.complete();
      async.flushMicrotasks();

      expect(saved, isEmpty);
      slow.dispose();
    });
  });

  test('syncNow saves at once, with no debounce', () async {
    await sync.syncNow();
    expect(saved.map((m) => m.serverId), ['s1']);
  });

  test('a failure in build or save does not stop later passes', () async {
    var fail = true;
    final flaky = LaunchSync(
      changes: changes.stream,
      vpnState: () => vpnState,
      selectedServer: () => selected,
      build: (s) async {
        if (fail) throw StateError('boom');
        return VpnConfigMessage(configJson: '{}', serverId: s.id);
      },
      save: (message) async => saved.add(message),
    );
    await flaky.syncNow(); // must not throw
    expect(saved, isEmpty);

    fail = false;
    await flaky.syncNow();
    expect(saved, hasLength(1));
  });

  test('after dispose, changes do nothing', () {
    fakeAsync((async) {
      sync.start();
      sync.dispose();
      changes.add(null);
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();

      expect(saved, isEmpty);
    });
  });
}
