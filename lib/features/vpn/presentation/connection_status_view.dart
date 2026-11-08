import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/subscriptions/data/vpn_server_display.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// Picks the accent: off — muted, busy — warn, on — ok, error — danger.
enum ConnectionPhase { off, busy, on, error }

ConnectionPhase connectionPhaseOf(VpnState state) => state.when(
  disconnected: () => ConnectionPhase.off,
  connecting: () => ConnectionPhase.busy,
  connected: (_, _, _, _) => ConnectionPhase.on,
  disconnecting: () => ConnectionPhase.busy,
  error: (_) => ConnectionPhase.error,
  blocked: (_) => ConnectionPhase.error,
);

/// What both home layouts say about the connection. The classic card and
/// the compact bar only render this, so the two never disagree.
class ConnectionStatusView {
  const ConnectionStatusView({
    required this.phase,
    required this.title,
    required this.subtitle,
    required this.server,
    required this.compactLabel,
  });

  factory ConnectionStatusView.from({
    required AppLocalizations l10n,
    required VpnState state,
    required bool hasSubscriptions,
    required VpnServer? selectedServer,
  }) {
    final server =
        state.whenOrNull(connected: (s, _, _, _) => s) ?? selectedServer;
    final serverName = server?.displayTitle ?? '';

    return state.when(
      disconnected: () => ConnectionStatusView(
        phase: ConnectionPhase.off,
        title: !hasSubscriptions
            ? l10n.statusNoServersTitle
            : server == null
            ? l10n.statusPickServerTitle
            : l10n.statusReadyTitle,
        subtitle: !hasSubscriptions
            ? l10n.statusNoServersSubtitle
            : server == null
            ? l10n.statusPickServerSubtitle
            : l10n.statusReadySubtitle,
        server: server,
        compactLabel: l10n.statusCompactOff,
      ),
      connecting: () => ConnectionStatusView(
        phase: ConnectionPhase.busy,
        title: l10n.statusConnectingTitle,
        subtitle: serverName,
        server: server,
        compactLabel: l10n.statusCompactConnecting,
      ),
      connected: (_, _, _, _) => ConnectionStatusView(
        phase: ConnectionPhase.on,
        title: l10n.statusConnectedTitle,
        subtitle: serverName,
        server: server,
        compactLabel: null,
      ),
      disconnecting: () => ConnectionStatusView(
        phase: ConnectionPhase.busy,
        title: l10n.statusDisconnectingTitle,
        subtitle: serverName,
        server: server,
        compactLabel: l10n.statusCompactDisconnecting,
      ),
      error: (message) => ConnectionStatusView(
        phase: ConnectionPhase.error,
        title: l10n.statusFailedTitle,
        subtitle: message,
        server: server,
        compactLabel: l10n.statusCompactFailed,
      ),
      blocked: (_) => ConnectionStatusView(
        phase: ConnectionPhase.error,
        title: l10n.statusBlockedTitle,
        subtitle: l10n.statusBlockedSubtitle,
        server: server,
        compactLabel: l10n.statusCompactBlocked,
      ),
    );
  }

  final ConnectionPhase phase;
  final String title;
  final String subtitle;

  /// The connected server, otherwise the selected one.
  final VpnServer? server;

  /// Status next to the traffic in the compact bar. Null while connected:
  /// the bar shows the live timer there instead.
  final String? compactLabel;
}
