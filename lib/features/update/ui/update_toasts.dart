import 'package:slipstream/core/models/app_release/app_release.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/core/service/update_service/update_service_cubit.dart';
import 'package:slipstream/core/utils/formatters.dart';

/// What the app does in answer to the user checking for updates.
sealed class UpdateFeedback {
  const UpdateFeedback();
}

final class OpenUpdateDialog extends UpdateFeedback {
  const OpenUpdateDialog();
}

final class ShowUpdateToast extends UpdateFeedback {
  const ShowUpdateToast(this.spec);

  final ToastSpec spec;
}

final class NoUpdateFeedback extends UpdateFeedback {
  const NoUpdateFeedback();
}

/// The answer for the state the updater is in. [installedVersion] is the
/// running app's "2.1.0 (36)", for the "up to date" line.
UpdateFeedback updateCheckFeedback(UpdateState state, String installedVersion) {
  return state.when(
    idle: () => const NoUpdateFeedback(),
    checking: () => const NoUpdateFeedback(),
    upToDate: () => ShowUpdateToast(
      ToastSpec(
        "You're up to date",
        subtitle: 'SLIPSTREAM $installedVersion IS THE LATEST',
      ),
    ),
    downloading: (release, receivedBytes) =>
        ShowUpdateToast(_downloadingToast(release, receivedBytes)),
    readyToInstall: (_, _) => const OpenUpdateDialog(),
    signatureConflict: (_, _) => const OpenUpdateDialog(),
    // The reason (network, GitHub, a release without an APK) is in the logs;
    // the user needs to know only that it did not work and can be retried.
    error: (_) => const ShowUpdateToast(
      ToastSpec(
        "Couldn't check for updates",
        subtitle: 'UPDATE SERVER UNREACHABLE · TRY AGAIN',
        kind: ToastKind.error,
      ),
    ),
  );
}

ToastSpec _downloadingToast(AppRelease release, int receivedBytes) {
  final size = release.sizeBytes;
  final percent = size > 0 ? (receivedBytes / size * 100).round() : 0;
  return ToastSpec(
    'Downloading update…',
    subtitle:
        '${percent.clamp(0, 100)}% · ${formatBytes(receivedBytes)} OF '
        '${formatBytes(size)}',
    kind: ToastKind.info,
  );
}

/// A tap on "check for updates" while an update is already downloaded,
/// downloading or in conflict shows that, instead of asking GitHub again.
bool isUpdateStateWorthShowing(UpdateState state) => state.maybeWhen(
  readyToInstall: (_, _) => true,
  downloading: (_, _) => true,
  signatureConflict: (_, _) => true,
  orElse: () => false,
);

/// Shown when the dialog is closed with an update ready: it will come up
/// again, the next launch checks for updates and finds the downloaded file.
const updateLaterToast = ToastSpec(
  "We'll remind you on next launch",
  kind: ToastKind.info,
);

/// [location] is what the export returned: where the APK went, or null when
/// copying failed. The path itself means nothing to the user.
ToastSpec saveApkToast(String? location) => location == null
    ? const ToastSpec(
        "Couldn't save the APK",
        subtitle: 'DOWNLOAD THE LATEST RELEASE FROM GITHUB',
        kind: ToastKind.error,
      )
    : const ToastSpec('APK saved', subtitle: 'SAVED TO DOWNLOADS');

/// What to tell the user after a tap on Install. Null when nothing needs
/// saying: the system installer opened, or the dialog itself switched to the
/// reinstall steps.
ToastSpec? installAttemptToast(InstallAttempt attempt) => switch (attempt) {
  InstallAttempt.launched || InstallAttempt.signatureConflict => null,
  InstallAttempt.permissionRequired => const ToastSpec(
    'Allow app installs',
    subtitle: 'ENABLE INSTALL UNKNOWN APPS · TAP INSTALL AGAIN',
    kind: ToastKind.info,
  ),
  InstallAttempt.failed => const ToastSpec(
    "Couldn't install update",
    subtitle: 'TRY AGAIN OR DOWNLOAD IT FROM GITHUB',
    kind: ToastKind.error,
  ),
};
