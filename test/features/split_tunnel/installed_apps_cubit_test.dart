import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/split_tunnel/cubit/installed_apps_cubit.dart';
import 'package:slipstream/features/split_tunnel/data/installed_apps_repository.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'fakes.dart';

void main() {
  InstalledAppsCubit cubitOver(FakeInstalledAppsApi api) =>
      InstalledAppsCubit(InstalledAppsRepository(api, Talker()));

  test('starts in loading', () {
    expect(
      cubitOver(FakeInstalledAppsApi()).state,
      isA<InstalledAppsLoading>(),
    );
  });

  test('load ends in loaded with the sorted apps and an empty query', () async {
    final api = FakeInstalledAppsApi(
      apps: [
        app('p.b', label: 'B'),
        app('p.a', label: 'A'),
      ],
    );
    final cubit = cubitOver(api);
    await cubit.load();
    final state = cubit.state as InstalledAppsLoaded;
    expect(state.apps.map((a) => a.label), ['A', 'B']);
    expect(state.query, '');
  });

  test('a native failure ends in failed', () async {
    final api = FakeInstalledAppsApi()..listError = StateError('boom');
    final cubit = cubitOver(api);
    await cubit.load();
    expect(cubit.state, isA<InstalledAppsFailed>());
  });

  test('load after a failure goes through loading again', () async {
    final api = FakeInstalledAppsApi()..listError = StateError('boom');
    final cubit = cubitOver(api);
    await cubit.load();
    api.listError = null;
    final seen = <Type>[];
    final sub = cubit.stream.listen((s) => seen.add(s.runtimeType));
    await cubit.load();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(seen, [InstalledAppsLoading, InstalledAppsLoaded]);
  });

  group('a page left while the list still loads', () {
    // The page closes its cubit in dispose. The load that is still waiting for
    // the native side must end quietly: an emit on a closed cubit throws.
    test('the list arriving after the close is dropped', () async {
      final api = FakeInstalledAppsApi(apps: [app('p.a')])
        ..listGate = Completer<void>();
      final cubit = cubitOver(api);
      final loading = cubit.load();
      await Future<void>.delayed(Duration.zero);

      await cubit.close();
      api.listGate!.complete();

      await expectLater(loading, completes);
    });

    test('a failure arriving after the close is dropped too', () async {
      final api = FakeInstalledAppsApi()
        ..listError = StateError('boom')
        ..listGate = Completer<void>();
      final cubit = cubitOver(api);
      final loading = cubit.load();
      await Future<void>.delayed(Duration.zero);

      await cubit.close();
      api.listGate!.complete();

      await expectLater(loading, completes);
    });

    test('an open cubit still gets the list that was held', () async {
      // The guard must not swallow the normal case.
      final api = FakeInstalledAppsApi(apps: [app('p.a')])
        ..listGate = Completer<void>();
      final cubit = cubitOver(api);
      final loading = cubit.load();
      await Future<void>.delayed(Duration.zero);

      api.listGate!.complete();
      await loading;

      expect(cubit.state, isA<InstalledAppsLoaded>());
    });
  });

  test('setQuery keeps the apps and changes the query', () async {
    final api = FakeInstalledAppsApi(apps: [app('p.a')]);
    final cubit = cubitOver(api);
    await cubit.load();
    cubit.setQuery('chr');
    final state = cubit.state as InstalledAppsLoaded;
    expect(state.query, 'chr');
    expect(state.apps, hasLength(1));
  });

  test('setQuery before the list is loaded changes nothing', () {
    final cubit = cubitOver(FakeInstalledAppsApi());
    cubit.setQuery('chr');
    expect(cubit.state, isA<InstalledAppsLoading>());
  });

  test('iconFor goes through the repository cache', () async {
    final bytes = Uint8List.fromList([1]);
    final api = FakeInstalledAppsApi(icons: {'p.a': bytes});
    final cubit = cubitOver(api);
    await cubit.iconFor('p.a');
    expect(await cubit.iconFor('p.a'), bytes);
    expect(api.iconCalls, 1);
  });
}
