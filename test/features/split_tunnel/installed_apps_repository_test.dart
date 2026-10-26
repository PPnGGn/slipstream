import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/split_tunnel/data/installed_apps_repository.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'fakes.dart';

void main() {
  InstalledAppsRepository repositoryOver(FakeInstalledAppsApi api) =>
      InstalledAppsRepository(api, Talker());

  group('load', () {
    test('sorts by label, ignoring case', () async {
      final api = FakeInstalledAppsApi(
        apps: [
          app('p.c', label: 'chrome'),
          app('p.a', label: 'Telegram'),
          app('p.b', label: 'Banking'),
        ],
      );
      final apps = await repositoryOver(api).load();
      expect(apps.map((a) => a.label), ['Banking', 'chrome', 'Telegram']);
    });

    test('keeps the system flag', () async {
      final api = FakeInstalledAppsApi(apps: [app('p.a', isSystem: true)]);
      final apps = await repositoryOver(api).load();
      expect(apps.single.isSystem, isTrue);
    });

    test('a native failure reaches the caller', () async {
      final api = FakeInstalledAppsApi()..listError = StateError('boom');
      expect(repositoryOver(api).load(), throwsStateError);
    });
  });

  group('icon', () {
    final bytes = Uint8List.fromList([1, 2, 3]);

    test('returns the bytes the native side rendered', () async {
      final api = FakeInstalledAppsApi(icons: {'p.a': bytes});
      expect(await repositoryOver(api).icon('p.a'), bytes);
    });

    test('is null when the app has no icon', () async {
      final api = FakeInstalledAppsApi();
      expect(await repositoryOver(api).icon('p.a'), isNull);
    });

    test('concurrent requests share one native call', () async {
      final api = FakeInstalledAppsApi(icons: {'p.a': bytes});
      final repository = repositoryOver(api);
      await Future.wait([repository.icon('p.a'), repository.icon('p.a')]);
      expect(api.iconCalls, 1);
    });

    test('a later request is served from the cache', () async {
      final api = FakeInstalledAppsApi(icons: {'p.a': bytes});
      final repository = repositoryOver(api);
      await repository.icon('p.a');
      await repository.icon('p.a');
      expect(api.iconCalls, 1);
    });

    test('a native failure gives null and is not cached', () async {
      final api = FakeInstalledAppsApi(icons: {'p.a': bytes})
        ..iconError = StateError('boom');
      final repository = repositoryOver(api);
      expect(await repository.icon('p.a'), isNull);

      api.iconError = null;
      expect(await repository.icon('p.a'), bytes);
      expect(api.iconCalls, 2);
    });
  });
}
