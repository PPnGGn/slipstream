import 'package:flutter/foundation.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/subscriptions/data/server_problem.dart';

/// Whether the app keeps the saved launch up to date. The saved launch is what
/// the quick settings tile (and Always-on VPN) starts, and only Android has
/// either; on iOS the tunnel is always started from the app.
bool isLaunchSyncSupported(TargetPlatform platform) =>
    platform == TargetPlatform.android;

/// Whether the saved launch may be rewritten in this state: only while nothing
/// runs. A restart of the service after the process died reads the saved
/// launch, and so does Reconnect from the kill switch's hold: overwriting it
/// under a live session would bring back a different server than the one that
/// was up. The session itself writes its launch when it starts.
bool isLaunchSavable(VpnState state) => state.maybeWhen(
  disconnected: () => true,
  // A failed earlier attempt may have been a bad moment, not a bad server.
  error: (_) => true,
  orElse: () => false,
);

/// The server whose launch to save now, or null to leave the saved one alone:
/// nothing selected, a session in progress, or a server that cannot connect
/// (the tile would only fail with it, and the previous launch still works).
VpnServer? launchServerToSave({
  required VpnState vpnState,
  required VpnServer? selectedServer,
}) {
  if (!isLaunchSavable(vpnState)) return null;
  if (selectedServer == null) return null;
  if (serverProblem(selectedServer) != null) return null;
  return selectedServer;
}
