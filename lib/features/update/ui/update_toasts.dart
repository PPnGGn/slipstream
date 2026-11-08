import 'package:slipstream/core/models/app_release/app_release.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/core/service/update_service/update_service_cubit.dart';
import 'package:slipstream/core/utils/formatters.dart';
import 'package:slipstream/l10n/l10n_context.dart';

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
UpdateFeedback updateCheckFeedback(
  AppLocalizations l10n,
  UpdateState state,
  String installedVersion,
) {
  return state.when(
    idle: () => const NoUpdateFeedback(),
    checking: () => const NoUpdateFeedback(),
    upToDate: () => ShowUpdateToast(
      ToastSpec(
        l10n.updateUpToDateTitle,
        subtitle: l10n.updateUpToDateHint(installedVersion),
      ),
    ),
    downloading: (release, receivedBytes) =>
        ShowUpdateToast(_downloadingToast(l10n, release, receivedBytes)),
    readyToInstall: (_, _) => const OpenUpdateDialog(),
    signatureConflict: (_, _) => const OpenUpdateDialog(),
    // The reason (network, GitHub, a release without an APK) is in the logs;
    // the user needs to know only that it did not work and can be retried.
    error: (_) => ShowUpdateToast(
      ToastSpec(
        l10n.updateCheckFailedTitle,
        subtitle: l10n.updateCheckFailedHint,
        kind: ToastKind.error,
      ),
    ),
  );
}

ToastSpec _downloadingToast(
  AppLocalizations l10n,
  AppRelease release,
  int receivedBytes,
) {
  final size = release.sizeBytes;
  final percent = size > 0 ? (receivedBytes / size * 100).round() : 0;
  return ToastSpec(
    l10n.updateDownloadingTitle,
    subtitle: l10n.updateDownloadingHint(
      percent.clamp(0, 100),
      formatBytes(receivedBytes),
      formatBytes(size),
    ),
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
ToastSpec updateLaterToast(AppLocalizations l10n) =>
    ToastSpec(l10n.updateLaterTitle, kind: ToastKind.info);

/// [location] is what the export returned: where the APK went, or null when
/// copying failed. The path itself means nothing to the user.
ToastSpec saveApkToast(AppLocalizations l10n, String? location) =>
    location == null
    ? ToastSpec(
        l10n.updateSaveFailedTitle,
        subtitle: l10n.updateSaveFailedHint,
        kind: ToastKind.error,
      )
    : ToastSpec(l10n.updateSavedTitle, subtitle: l10n.updateSavedHint);

/// What to tell the user after a tap on Install. Null when nothing needs
/// saying: the system installer opened, or the dialog itself switched to the
/// reinstall steps.
ToastSpec? installAttemptToast(AppLocalizations l10n, InstallAttempt attempt) =>
    switch (attempt) {
      InstallAttempt.launched || InstallAttempt.signatureConflict => null,
      InstallAttempt.permissionRequired => ToastSpec(
        l10n.updateAllowInstallsTitle,
        subtitle: l10n.updateAllowInstallsHint,
        kind: ToastKind.info,
      ),
      InstallAttempt.failed => ToastSpec(
        l10n.updateInstallFailedTitle,
        subtitle: l10n.updateInstallFailedHint,
        kind: ToastKind.error,
      ),
    };
