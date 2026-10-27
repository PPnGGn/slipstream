import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/core/models/app_release/app_release.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/core/service/toast/toast_cubit.dart';
import 'package:slipstream/core/service/update_service/update_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/theme/data/theme_store.dart';
import 'package:slipstream/features/update/data/update_check.dart';
import 'package:slipstream/features/update/data/update_repository.dart';
import 'package:slipstream/features/update/data/updater_api.g.dart';
import 'package:slipstream/features/update/ui/widgets/update_dialog.dart';
import 'package:talker_flutter/talker_flutter.dart';

const _release = AppRelease(
  version: '2.1.1',
  buildNumber: 37,
  tagName: 'v2.1.1+37',
  downloadUrl: 'https://example.com/slipstream-android.apk',
  sizeBytes: 19293798,
  notes: ['Search in split tunneling', 'Fixed reconnect loop'],
);

class _FakeRepository extends Fake implements UpdateRepository {
  AppRelease release = _release;
  Result<InstallOutcome> installAnswer = const Success(InstallOutcome.launched);
  Completer<void>? installGate;
  String? exportLocation = '/storage/Download/slipstream.apk';
  int uninstalls = 0;

  @override
  Future<Result<UpdateCheck>> checkAndResolveCache() async =>
      Success(UpdateCheckReady(release: release, filePath: 'update.apk'));

  @override
  Future<Result<InstallOutcome>> install(String filePath) async {
    await installGate?.future;
    return installAnswer;
  }

  @override
  Future<String?> exportApk(AppRelease release, String filePath) async =>
      exportLocation;

  @override
  Future<void> uninstallForReinstall() async => uninstalls++;
}

class _FakeInstaller extends Fake implements UpdateInstaller {
  @override
  Future<AppVersionMessage> getAppVersion() async =>
      AppVersionMessage(version: '2.1.0', buildNumber: 36);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRepository repository;
  late UpdateServiceCubit updates;
  late ToastCubit toasts;

  Future<void> openDialog(
    WidgetTester tester, {
    bool conflict = false,
    List<String>? notes,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final theme = AppThemeCubit(
      themeStore: ThemeStore(await SharedPreferences.getInstance()),
    );
    repository = _FakeRepository();
    if (notes != null) repository.release = _release.copyWith(notes: notes);
    updates = UpdateServiceCubit(repository: repository, talker: Talker());
    toasts = ToastCubit();
    await GetIt.I.reset();
    GetIt.I
      ..registerSingleton<AppColors>(AppColors(themeCubit: theme))
      ..registerSingleton<UpdateServiceCubit>(updates)
      ..registerSingleton<ToastCubit>(toasts)
      ..registerSingleton<UpdateInstaller>(_FakeInstaller());

    await updates.check();
    if (conflict) {
      repository.installAnswer = const Success(InstallOutcome.signatureConflict);
      await updates.install();
      repository.installAnswer = const Success(InstallOutcome.launched);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showUpdateDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // A toast keeps a timer, and the test body must end with none pending (this
  // check runs before tearDown), so every test hides its toast at the end.
  void testDialog(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await body(tester);
      toasts.dismiss();
    });
  }

  setUp(resetUpdateDialogGuardForTest);

  tearDown(() async {
    await updates.close();
    await toasts.close();
    await GetIt.I.reset();
  });

  group('an update ready to install', () {
    testDialog('shows what the content says', (tester) async {
      await openDialog(tester);

      expect(find.text('DOWNLOADED · 18.4 MB'), findsOneWidget);
      expect(find.text('Update ready to install'), findsOneWidget);
      expect(find.text('2.1.0 (36)'), findsOneWidget);
      expect(find.text('2.1.1 (37)'), findsOneWidget);
      expect(find.text("WHAT'S NEW"), findsOneWidget);
      expect(find.text('Search in split tunneling'), findsOneWidget);
      expect(find.text('Fixed reconnect loop'), findsOneWidget);
      expect(
        find.text('System installer opens · reconnect VPN after update'),
        findsOneWidget,
      );
    });

    testDialog('has no What\'s new block when the release has no notes', (
      tester,
    ) async {
      await openDialog(tester, notes: const []);

      expect(find.text("WHAT'S NEW"), findsNothing);
      expect(find.text('Update ready to install'), findsOneWidget);
    });

    testDialog('Later closes it and promises a reminder', (tester) async {
      await openDialog(tester);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      expect(find.text('Update ready to install'), findsNothing);
      expect(toasts.state!.title, "We'll remind you on next launch");
      expect(
        updates.state.maybeWhen(
          readyToInstall: (_, _) => true,
          orElse: () => false,
        ),
        isTrue,
      );
    });

    testDialog('a tap on the dimmed background does the same as Later', (
      tester,
    ) async {
      await openDialog(tester);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.text('Update ready to install'), findsNothing);
      expect(toasts.state!.title, "We'll remind you on next launch");
    });

    testDialog('Install shows "Installing…" while the installer starts', (
      tester,
    ) async {
      await openDialog(tester);
      repository.installGate = Completer<void>();

      await tester.tap(find.text('Install'));
      await tester.pump();

      expect(find.text('Installing…'), findsOneWidget);

      repository.installGate!.complete();
      await tester.pumpAndSettle();
    });

    testDialog('a launched installer closes the dialog quietly', (
      tester,
    ) async {
      await openDialog(tester);

      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();

      expect(find.text('Update ready to install'), findsNothing);
      expect(toasts.state, isNull);
    });

    testDialog('a missing permission keeps it open with a hint', (
      tester,
    ) async {
      await openDialog(tester);
      repository.installAnswer = const Success(
        InstallOutcome.permissionRequired,
      );

      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();

      expect(find.text('Update ready to install'), findsOneWidget);
      expect(find.text('Install'), findsOneWidget);
      expect(toasts.state!.title, 'Allow app installs');
    });

    testDialog('a failure keeps it open, ready for another try', (
      tester,
    ) async {
      await openDialog(tester);
      repository.installAnswer = const Failure('INSTALL_FAILED');

      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();

      expect(find.text('Update ready to install'), findsOneWidget);
      expect(find.text('Install'), findsOneWidget);
      expect(toasts.state!.title, "Couldn't install update");
    });
  });

  group('a signature conflict', () {
    testDialog('shows the reinstall steps', (tester) async {
      await openDialog(tester, conflict: true);

      expect(find.text('SIGNATURE MISMATCH'), findsOneWidget);
      expect(find.text('Reinstall required'), findsOneWidget);
      expect(find.text('WHAT TO DO'), findsOneWidget);
      expect(find.text('Save the APK'), findsOneWidget);
      expect(find.text('Uninstall Slipstream'), findsOneWidget);
      expect(
        find.text('Uninstalling also removes your saved subscriptions'),
        findsOneWidget,
      );
    });

    testDialog('Save APK confirms with a toast and stays open', (
      tester,
    ) async {
      await openDialog(tester, conflict: true);

      await tester.tap(find.text('Save APK'));
      await tester.pumpAndSettle();

      expect(toasts.state!.title, 'APK saved');
      expect(find.text('Reinstall required'), findsOneWidget);
    });

    testDialog('Save APK says so when the copy fails', (tester) async {
      await openDialog(tester, conflict: true);
      repository.exportLocation = null;

      await tester.tap(find.text('Save APK'));
      await tester.pumpAndSettle();

      expect(toasts.state!.title, "Couldn't save the APK");
    });

    testDialog('Uninstall asks the system to remove the app', (tester) async {
      await openDialog(tester, conflict: true);

      await tester.tap(find.text('Uninstall'));
      await tester.pumpAndSettle();

      expect(repository.uninstalls, 1);
    });

    testDialog('Close drops the update without a reminder', (tester) async {
      await openDialog(tester, conflict: true);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Reinstall required'), findsNothing);
      expect(toasts.state, isNull);
      expect(
        updates.state.maybeWhen(idle: () => true, orElse: () => false),
        isTrue,
      );
    });
  });
}
