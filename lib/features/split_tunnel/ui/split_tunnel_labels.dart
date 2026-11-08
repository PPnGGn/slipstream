import 'package:slipstream/features/split_tunnel/data/split_tunnel_mode.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_settings.dart';
import 'package:slipstream/l10n/l10n_context.dart';

String splitTunnelHint(AppLocalizations l10n, SplitTunnelMode mode) =>
    switch (mode) {
      SplitTunnelMode.proxy => l10n.splitHintProxy,
      SplitTunnelMode.bypass => l10n.splitHintBypass,
    };

String splitTunnelCounter(
  AppLocalizations l10n, {
  required int selected,
  required int total,
  required SplitTunnelMode mode,
}) => mode == SplitTunnelMode.proxy
    ? l10n.splitCounterProxied(selected, total)
    : l10n.splitCounterBypassed(selected, total);

String splitTunnelSummary(AppLocalizations l10n, SplitTunnelSettings settings) {
  if (!settings.enabled) return l10n.commonOff;
  if (settings.packages.isEmpty) return l10n.splitSummaryNone;
  final mode = switch (settings.mode) {
    SplitTunnelMode.proxy => l10n.splitModeProxyShort,
    SplitTunnelMode.bypass => l10n.splitModeBypassShort,
  };
  return '$mode · ${l10n.splitAppsCount(settings.packages.length)}';
}
