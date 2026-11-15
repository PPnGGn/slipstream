import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/app_release/app_release.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/features/routing/data/local_proxy_client.dart';
import 'package:slipstream/features/update/data/github_release_api.dart';
import 'package:slipstream/features/update/data/update_repository.dart';
import 'package:slipstream/features/update/data/updater_api.g.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../../helpers/fake_unix_proxy.dart';

/// The Android side of the updater, with answers set by each test.
class _FakeInstaller extends Fake implements UpdateInstaller {
  bool canInstall = true;
  bool signatureMatches = true;
  InstallResult installResult = InstallResult(successful: true);
  Object? installThrows;

  int settingsOpened = 0;
  final installed = <String>[];

  @override
  Future<bool> canInstallPackages() async => canInstall;

  @override
  Future<void> openInstallSettings() async => settingsOpened++;

  @override
  Future<bool> apkSignatureMatchesInstalled(String filePath) async =>
      signatureMatches;

  @override
  Future<InstallResult> installApk(String filePath) async {
    installed.add(filePath);
    final error = installThrows;
    if (error != null) throw error;
    return installResult;
  }
}

void main() {
  late _FakeInstaller installer;
  late UpdateRepository repository;

  setUp(() {
    installer = _FakeInstaller();
    repository = UpdateRepository(Talker(), installer, Directory.systemTemp);
  });

  tearDown(() => repository.dispose());

  group('install', () {
    test('without the permission it opens the settings and says so', () async {
      installer.canInstall = false;

      final result = await repository.install('update.apk');

      expect(
        (result as Success<InstallOutcome>).data,
        InstallOutcome.permissionRequired,
      );
      expect(installer.settingsOpened, 1);
      expect(installer.installed, isEmpty);
    });

    test('a different signature is a conflict, nothing is installed', () async {
      installer.signatureMatches = false;

      final result = await repository.install('update.apk');

      expect(
        (result as Success<InstallOutcome>).data,
        InstallOutcome.signatureConflict,
      );
      expect(installer.installed, isEmpty);
    });

    test('when the system installer starts, it is launched', () async {
      final result = await repository.install('update.apk');

      expect((result as Success<InstallOutcome>).data, InstallOutcome.launched);
      expect(installer.installed, ['update.apk']);
    });

    test('an installer error is a failure', () async {
      installer.installResult = InstallResult(
        successful: false,
        error: 'INSTALL_FAILED_INSUFFICIENT_STORAGE',
      );

      final result = await repository.install('update.apk');

      expect(result, isA<Failure<InstallOutcome>>());
    });

    test('a crash of the bridge is a failure, not an exception', () async {
      installer.installThrows = StateError('bridge is gone');

      final result = await repository.install('update.apk');

      expect(result, isA<Failure<InstallOutcome>>());
    });
  });

  group('local proxy routing', () {
    late FakeUnixProxy fake;

    setUp(() async {
      fake = await FakeUnixProxy.start(
        answer: 'HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\n\r\n',
      );
    });
    tearDown(() => fake.close());

    test('GithubReleaseApi routes release check through the local proxy', () async {
      var reported = 'p1';
      final provider = LocalProxyProvider(
        FakeVpnConnection(() async {
          final message = fake.message(reported);
          reported = 'p2';
          fake.pass = 'p2';
          return message;
        }),
        Talker(settings: TalkerSettings(useConsoleLogs: false)),
      );

      await expectLater(
        GithubReleaseApi(proxy: provider).fetchLatest(),
        throwsA(anything),
      );

      expect(fake.authorized, [false, true]);
    });

    test('downloadApk routes APK download through the local proxy', () async {
      final dir = await Directory.systemTemp.createTemp('slip_upd');
      addTearDown(() => dir.delete(recursive: true));

      final provider = LocalProxyProvider(
        FakeVpnConnection(() async => fake.message()),
        Talker(settings: TalkerSettings(useConsoleLogs: false)),
      );
      final repo = UpdateRepository(
        Talker(settings: TalkerSettings(useConsoleLogs: false)),
        installer,
        dir,
        proxy: provider,
      );
      addTearDown(repo.dispose);

      const release = AppRelease(
        version: '2.1.8',
        buildNumber: 46,
        tagName: 'v2.1.8+46',
        downloadUrl: 'https://github.com/PPnGGn/slipstream/releases/download/v2.1.8/slipstream-android.apk',
        sizeBytes: 100,
      );

      await expectLater(
        repo.downloadApk(release, toPath: '${dir.path}/app.apk').drain<void>(),
        throwsA(anything),
      );

      expect(fake.authorized, [true]);
    });
  });
}
