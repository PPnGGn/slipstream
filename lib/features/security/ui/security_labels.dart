import 'package:slipstream/l10n/l10n_context.dart';

/// Subtitle of the kill switch row: what it does right now.
String killSwitchSubtitle(AppLocalizations l10n, {required bool enabled}) =>
    enabled ? l10n.killSwitchOn : l10n.killSwitchOff;

/// Subtitle of the IPv6 row: what the setting does right now.
String ipv6Subtitle(AppLocalizations l10n, {required bool enabled}) =>
    enabled ? l10n.ipv6On : l10n.ipv6Off;
