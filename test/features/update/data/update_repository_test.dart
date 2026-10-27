import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/features/update/data/update_repository.dart';
import 'package:slipstream/features/update/data/updater_api.g.dart';
import 'package:talker_flutter/talker_flutter.dart';

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
    repository = UpdateRepository(
      Talker(),
      installer,
      Directory.systemTemp,
    );
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

      expect(
        (result as Success<InstallOutcome>).data,
        InstallOutcome.launched,
      );
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
}
