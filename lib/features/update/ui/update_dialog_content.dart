import 'package:slipstream/core/models/app_release/app_release.dart';
import 'package:slipstream/core/service/update_service/update_service_cubit.dart';
import 'package:slipstream/core/utils/formatters.dart';

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
  UpdateState state,
  String? installedVersion,
) {
  return state.maybeWhen(
    readyToInstall: (release, _) => UpdateDialogContent(
      kind: UpdateDialogKind.ready,
      eyebrow: 'DOWNLOADED · ${formatBytes(release.sizeBytes).toUpperCase()}',
      title: 'Update ready to install',
      fromVersion: installedVersion,
      toVersion: _versionOf(release),
      sectionLabel: "WHAT'S NEW",
      items: release.notes,
      hint: 'System installer opens · reconnect VPN after update',
    ),
    signatureConflict: (release, _) => UpdateDialogContent(
      kind: UpdateDialogKind.reinstall,
      eyebrow: 'SIGNATURE MISMATCH',
      title: 'Reinstall required',
      fromVersion: installedVersion,
      toVersion: _versionOf(release),
      sectionLabel: 'WHAT TO DO',
      items: [
        'Save the APK',
        'Uninstall Slipstream',
        'Open the saved APK to install v${release.version}',
      ],
      hint: 'Uninstalling also removes your saved subscriptions',
    ),
    orElse: () => null,
  );
}
