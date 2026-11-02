import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/subscriptions/data/server_problem.dart';

/// The server to connect to when the app opens, or null to leave things as
/// they are. Connects only when all of these hold:
///  - the user turned it on;
///  - the VPN permission is already granted (asking now would pop the system
///    dialog at launch, or take the tunnel from another VPN app);
///  - nothing is running: a tunnel started from the tile before the app opened,
///    one still coming up, or the kill switch's hold are left alone, because a
///    second start would tear the first one down;
///  - a server is selected, and it is one that can connect.
VpnServer? autoConnectServer({
  required bool enabled,
  required bool permissionGranted,
  required VpnState vpnState,
  required VpnServer? selectedServer,
}) {
  if (!enabled || !permissionGranted) return null;
  // An old selection may point at a server the provider sent without its key.
  if (selectedServer != null && serverProblem(selectedServer) != null) {
    return null;
  }
  final idle = vpnState.maybeWhen(
    disconnected: () => true,
    // A failed earlier attempt may have been a bad moment, not a bad server.
    error: (_) => true,
    orElse: () => false,
  );
  return idle ? selectedServer : null;
}
