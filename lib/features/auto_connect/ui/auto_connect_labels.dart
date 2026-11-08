import 'package:slipstream/l10n/l10n_context.dart';

/// Subtitle of the auto-connect row: what happens at launch right now.
String autoConnectSubtitle(AppLocalizations l10n, {required bool enabled}) =>
    enabled ? l10n.autoConnectOn : l10n.autoConnectOff;
