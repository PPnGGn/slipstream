import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// What a long press on a server says: it was pinned or unpinned. [serverName]
/// is the title without the flag emoji (`displayTitle`).
ToastSpec favoriteToast(
  AppLocalizations l10n, {
  required bool added,
  required String serverName,
}) => ToastSpec(
  added ? l10n.favAddedTitle : l10n.favRemovedTitle,
  subtitle: serverName.toUpperCase(),
  kind: added ? ToastKind.success : ToastKind.info,
);
