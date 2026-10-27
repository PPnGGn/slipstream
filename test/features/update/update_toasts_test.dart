import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/app_release/app_release.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/core/service/update_service/update_service_cubit.dart';
import 'package:slipstream/features/update/ui/update_toasts.dart';

const _release = AppRelease(
  version: '2.1.1',
  buildNumber: 37,
  tagName: 'v2.1.1+37',
  downloadUrl: 'https://example.com/slipstream-android.apk',
  sizeBytes: 20 * 1024 * 1024,
);

void main() {
  group('updateCheckFeedback', () {
    const installed = '2.1.0 (36)';

    Matcher showsToast(ToastSpec spec) => isA<ShowUpdateToast>().having(
      (f) => f.spec,
      'spec',
      spec,
    );

    test('an up-to-date app says which version is the latest', () {
      expect(
        updateCheckFeedback(const UpdateState.upToDate(), installed),
        showsToast(
          const ToastSpec(
            "You're up to date",
            subtitle: 'SLIPSTREAM 2.1.0 (36) IS THE LATEST',
          ),
        ),
      );
    });

    test('a failed check is an error with a hint, no raw exception', () {
      expect(
        updateCheckFeedback(
          const UpdateState.error('Failed to check for updates: SocketException'),
          installed,
        ),
        showsToast(
          const ToastSpec(
            "Couldn't check for updates",
            subtitle: 'UPDATE SERVER UNREACHABLE · TRY AGAIN',
            kind: ToastKind.error,
          ),
        ),
      );
    });

    test('a running download shows its progress', () {
      expect(
        updateCheckFeedback(
          UpdateState.downloading(_release, receivedBytes: 5 * 1024 * 1024),
          installed,
        ),
        showsToast(
          const ToastSpec(
            'Downloading update…',
            subtitle: '25% · 5.0 MB OF 20.0 MB',
            kind: ToastKind.info,
          ),
        ),
      );
    });

    test('progress never goes past 100%', () {
      final feedback = updateCheckFeedback(
        UpdateState.downloading(_release, receivedBytes: 30 * 1024 * 1024),
        installed,
      );

      expect((feedback as ShowUpdateToast).spec.subtitle, startsWith('100%'));
    });

    test('a downloaded update and a signature conflict open the dialog', () {
      expect(
        updateCheckFeedback(
          const UpdateState.readyToInstall(_release, 'update.apk'),
          installed,
        ),
        isA<OpenUpdateDialog>(),
      );
      expect(
        updateCheckFeedback(
          const UpdateState.signatureConflict(_release, 'update.apk'),
          installed,
        ),
        isA<OpenUpdateDialog>(),
      );
    });

    test('idle and checking have nothing to say', () {
      expect(
        updateCheckFeedback(const UpdateState.idle(), installed),
        isA<NoUpdateFeedback>(),
      );
      expect(
        updateCheckFeedback(const UpdateState.checking(), installed),
        isA<NoUpdateFeedback>(),
      );
    });
  });

  group('reusableUpdateState', () {
    test('a ready, downloading or conflicting update is shown as it is', () {
      expect(
        isUpdateStateWorthShowing(
          const UpdateState.readyToInstall(_release, 'update.apk'),
        ),
        isTrue,
      );
      expect(
        isUpdateStateWorthShowing(
          UpdateState.downloading(_release, receivedBytes: 1),
        ),
        isTrue,
      );
      expect(
        isUpdateStateWorthShowing(
          const UpdateState.signatureConflict(_release, 'update.apk'),
        ),
        isTrue,
      );
    });

    test('every other state means a new check on tap', () {
      expect(isUpdateStateWorthShowing(const UpdateState.idle()), isFalse);
      expect(isUpdateStateWorthShowing(const UpdateState.upToDate()), isFalse);
      expect(isUpdateStateWorthShowing(const UpdateState.error('x')), isFalse);
    });
  });

  test('Later promises a reminder, and the reminder is real', () {
    expect(
      updateLaterToast,
      const ToastSpec(
        "We'll remind you on next launch",
        kind: ToastKind.info,
      ),
    );
  });

  group('saveApkToast', () {
    test('a saved APK is a success, without the file path', () {
      expect(
        saveApkToast('/storage/emulated/0/Download/slipstream-2.1.1.apk'),
        const ToastSpec('APK saved', subtitle: 'SAVED TO DOWNLOADS'),
      );
    });

    test('a failed save points to GitHub', () {
      expect(
        saveApkToast(null),
        const ToastSpec(
          "Couldn't save the APK",
          subtitle: 'DOWNLOAD THE LATEST RELEASE FROM GITHUB',
          kind: ToastKind.error,
        ),
      );
    });
  });

  group('installAttemptToast', () {
    test('the system installer opening needs no toast', () {
      expect(installAttemptToast(InstallAttempt.launched), isNull);
    });

    test('a signature conflict is shown by the dialog itself', () {
      expect(installAttemptToast(InstallAttempt.signatureConflict), isNull);
    });

    test('a missing permission tells what to do and to tap Install again', () {
      expect(
        installAttemptToast(InstallAttempt.permissionRequired),
        const ToastSpec(
          'Allow app installs',
          subtitle: 'ENABLE INSTALL UNKNOWN APPS · TAP INSTALL AGAIN',
          kind: ToastKind.info,
        ),
      );
    });

    test('a failure is plain, with no raw installer text', () {
      expect(
        installAttemptToast(InstallAttempt.failed),
        const ToastSpec(
          "Couldn't install update",
          subtitle: 'TRY AGAIN OR DOWNLOAD IT FROM GITHUB',
          kind: ToastKind.error,
        ),
      );
    });
  });
}
