import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/features/client_identity/data/client_identity_repository.dart';
import 'package:slipstream/features/client_identity/data/client_identity_store.dart';
import 'package:slipstream/features/client_identity/data/hwid.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const oldHwid = '11111111-2222-3333-4444-555555555555';

  Future<SharedPreferences> prefsWith(Map<String, Object> values) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  ClientIdentityRepository repoOn(
    SharedPreferences prefs,
    FakeDeviceInfoApi api, {
    ClientIdentityStore? store,
  }) => ClientIdentityRepository(
    store ?? ClientIdentityStore(prefs),
    api,
    Talker(),
  );

  group('HWID source', () {
    test('uses the hash of the device ID and saves it', () async {
      final prefs = await prefsWith({});
      final repo = repoOn(prefs, FakeDeviceInfoApi(deviceId: 'abc'));

      final identity = await repo.current();

      expect(identity.hwid, equals(hwidFromDeviceId('abc')));
      expect(prefs.getString('client_hwid_real'), equals(identity.hwid));
    });

    test('without a device ID makes a random HWID and keeps it', () async {
      final prefs = await prefsWith({});

      final first = await repoOn(prefs, FakeDeviceInfoApi()).current();
      final second = await repoOn(prefs, FakeDeviceInfoApi()).current();

      expect(isValidHwid(first.hwid), isTrue);
      expect(second.hwid, equals(first.hwid));
    });

    test('treats an empty device ID as missing', () async {
      final prefs = await prefsWith({'client_hwid_real': oldHwid});
      final repo = repoOn(prefs, FakeDeviceInfoApi(deviceId: ''));

      expect((await repo.current()).hwid, equals(oldHwid));
    });

    test('without a device ID falls back to the stored HWID', () async {
      final prefs = await prefsWith({'client_hwid_real': oldHwid});
      final repo = repoOn(prefs, FakeDeviceInfoApi());

      expect((await repo.current()).hwid, equals(oldHwid));
    });

    test('the device ID wins over a stored HWID (restored backup)', () async {
      final prefs = await prefsWith({'client_hwid_real': oldHwid});
      final repo = repoOn(prefs, FakeDeviceInfoApi(deviceId: 'abc'));

      final identity = await repo.current();

      expect(identity.hwid, equals(hwidFromDeviceId('abc')));
      expect(prefs.getString('client_hwid_real'), equals(identity.hwid));
    });

    test('a native error does not crash and falls back', () async {
      final prefs = await prefsWith({});
      final api = FakeDeviceInfoApi(
        error: PlatformException(code: 'channel-error'),
      );

      final identity = await repoOn(prefs, api).current();

      expect(isValidHwid(identity.hwid), isTrue);
    });

    test('a failed save still returns the identity', () async {
      final prefs = await prefsWith({});
      final repo = repoOn(
        prefs,
        FakeDeviceInfoApi(deviceId: 'abc'),
        store: FailingWriteStore(prefs),
      );

      expect((await repo.current()).hwid, equals(hwidFromDeviceId('abc')));
    });
  });

  group('identity fields', () {
    test('carries the default User-Agent and the device info', () async {
      final prefs = await prefsWith({});
      final repo = repoOn(
        prefs,
        FakeDeviceInfoApi(
          deviceId: 'abc',
          os: 'Android',
          osVersion: '14',
          model: 'Pixel 8',
        ),
      );

      final identity = await repo.current();

      expect(
        identity.userAgent,
        equals(ClientIdentityRepository.defaultUserAgent),
      );
      expect(identity.deviceOs, equals('Android'));
      expect(identity.osVersion, equals('14'));
      expect(identity.deviceModel, equals('Pixel 8'));
    });

    test('the default User-Agent starts with Happ/', () {
      expect(ClientIdentityRepository.defaultUserAgent, startsWith('Happ/'));
    });

    test('device info is null when the native call fails', () async {
      final prefs = await prefsWith({});
      final api = FakeDeviceInfoApi(error: StateError('boom'));

      final identity = await repoOn(prefs, api).current();

      expect(identity.deviceOs, isNull);
      expect(identity.osVersion, isNull);
      expect(identity.deviceModel, isNull);
    });
  });

  group('native call count', () {
    test('concurrent callers share one native call', () async {
      final prefs = await prefsWith({});
      final api = FakeDeviceInfoApi();
      final repo = repoOn(prefs, api);

      final results = await Future.wait([repo.current(), repo.current()]);

      expect(api.calls, equals(1));
      expect(results[0].hwid, equals(results[1].hwid));
    });

    test('later calls reuse the first result', () async {
      final prefs = await prefsWith({});
      final api = FakeDeviceInfoApi(deviceId: 'abc');
      final repo = repoOn(prefs, api);

      await repo.current();
      await repo.current();

      expect(api.calls, equals(1));
    });
  });
}
