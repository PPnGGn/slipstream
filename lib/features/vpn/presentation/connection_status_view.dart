import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/subscriptions/data/vpn_server_display.dart';

/// Picks the accent: off — muted, busy — warn, on — ok, error — danger.
enum ConnectionPhase { off, busy, on, error }

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
            ? 'No servers yet'
            : server == null
            ? 'Pick a server'
            : 'Ready to connect',
        subtitle: !hasSubscriptions
            ? 'Add a subscription below'
            : server == null
            ? 'Choose one from the list below'
            : 'Tap the ring to start',
        server: server,
        compactLabel: 'off',
      ),
      connecting: () => ConnectionStatusView(
        phase: ConnectionPhase.busy,
        title: 'Establishing tunnel…',
        subtitle: serverName,
        server: server,
        compactLabel: 'connecting…',
      ),
      connected: (_, _, _, _) => ConnectionStatusView(
        phase: ConnectionPhase.on,
        title: 'Connected',
        subtitle: serverName,
        server: server,
        compactLabel: null,
      ),
      disconnecting: () => ConnectionStatusView(
        phase: ConnectionPhase.busy,
        title: 'Disconnecting…',
        subtitle: serverName,
        server: server,
        compactLabel: 'disconnecting…',
      ),
      error: (message) => ConnectionStatusView(
        phase: ConnectionPhase.error,
        title: 'Connection failed',
        subtitle: message,
        server: server,
        compactLabel: 'failed',
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
