import 'package:slipstream/core/models/app_release/app_release.dart';
import 'package:slipstream/core/service/update_service/update_service_cubit.dart';
import 'package:slipstream/core/utils/formatters.dart';
import 'package:slipstream/l10n/l10n_context.dart';

enum UpdateDialogKind { ready, reinstall }

/// Everything the update card says, decided away from the widget: the card
/// only lays these values out.
class UpdateDialogContent {
  const UpdateDialogContent({
    required this.kind,
    required this.eyebrow,
    required this.title,
    required this.toVersion,
    required this.sectionLabel,
    required this.items,
    required this.hint,
    this.fromVersion,
  });

  final UpdateDialogKind kind;
  final String eyebrow;
  final String title;
  final String? fromVersion;
  final String toVersion;
  final String sectionLabel;
  final List<String> items;
  final String hint;
}

String _versionOf(AppRelease release) =>
    '${release.version} (${release.buildNumber})';

UpdateDialogContent? updateDialogContent(
  AppLocalizations l10n,
  UpdateState state,
  String? installedVersion,
) {
  return state.maybeWhen(
    readyToInstall: (release, _) => UpdateDialogContent(
      kind: UpdateDialogKind.ready,
      eyebrow: l10n.updateEyebrowDownloaded(
        formatBytes(release.sizeBytes).toUpperCase(),
      ),
      title: l10n.updateReadyTitle,
      fromVersion: installedVersion,
      toVersion: _versionOf(release),
      sectionLabel: l10n.updateWhatsNew,
      items: release.notes,
      hint: l10n.updateReadyHint,
    ),
    signatureConflict: (release, _) => UpdateDialogContent(
      kind: UpdateDialogKind.reinstall,
      eyebrow: l10n.updateMismatchEyebrow,
      title: l10n.updateReinstallTitle,
      fromVersion: installedVersion,
      toVersion: _versionOf(release),
      sectionLabel: l10n.updateWhatToDo,
      items: [
        l10n.updateStepSave,
        l10n.updateStepUninstall,
        l10n.updateStepOpen(release.version),
      ],
      hint: l10n.updateReinstallHint,
    ),
    orElse: () => null,
  );
}
