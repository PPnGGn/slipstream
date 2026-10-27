import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/app_release/app_release.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/core/service/update_service/update_service_cubit.dart';
import 'package:slipstream/features/update/data/update_check.dart';
import 'package:slipstream/features/update/data/update_repository.dart';
import 'package:talker_flutter/talker_flutter.dart';

const _release = AppRelease(
  version: '2.1.1',
  buildNumber: 37,
  tagName: 'v2.1.1+37',
  downloadUrl: 'https://example.com/slipstream-android.apk',
  sizeBytes: 10,
);

/// Answers a check with a downloaded update and install with [installAnswer].
class _FakeRepository extends Fake implements UpdateRepository {
  Result<InstallOutcome> installAnswer = const Success(InstallOutcome.launched);
  final installed = <String>[];

  @override
  Future<Result<UpdateCheck>> checkAndResolveCache() async => const Success(
    UpdateCheckReady(release: _release, filePath: 'update.apk'),
  );

  @override
  Future<Result<InstallOutcome>> install(String filePath) async {
    installed.add(filePath);
    return installAnswer;
  }
}

void main() {
  late _FakeRepository repository;
  late UpdateServiceCubit cubit;

  setUp(() async {
    repository = _FakeRepository();
    cubit = UpdateServiceCubit(repository: repository, talker: Talker());
    await cubit.check();
  });

  tearDown(() => cubit.close());

  bool isReady() => cubit.state.maybeWhen(
    readyToInstall: (_, _) => true,
    orElse: () => false,
  );

  group('install', () {
    test('only works once an update is downloaded', () async {
      final idle = UpdateServiceCubit(
        repository: repository,
        talker: Talker(),
      );
      addTearDown(idle.close);

      expect(await idle.install(), InstallAttempt.failed);
      expect(repository.installed, isEmpty);
    });

    test('a launched installer is reported, the update stays ready', () async {
      expect(await cubit.install(), InstallAttempt.launched);
      expect(isReady(), isTrue);
    });

    test('a missing permission is reported and does not break the state', () async {
      repository.installAnswer = const Success(
        InstallOutcome.permissionRequired,
      );

      expect(await cubit.install(), InstallAttempt.permissionRequired);
      expect(isReady(), isTrue);
    });

    test('a failure is reported and the update stays ready to retry', () async {
      repository.installAnswer = const Failure('INSTALL_FAILED');

      expect(await cubit.install(), InstallAttempt.failed);
      expect(isReady(), isTrue);
    });

    test('a signature conflict moves to the reinstall state', () async {
      repository.installAnswer = const Success(InstallOutcome.signatureConflict);

      expect(await cubit.install(), InstallAttempt.signatureConflict);
      expect(
        cubit.state.maybeWhen(
          signatureConflict: (_, _) => true,
          orElse: () => false,
        ),
        isTrue,
      );
    });
  });
}
