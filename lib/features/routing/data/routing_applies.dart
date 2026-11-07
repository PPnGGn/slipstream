import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/routing/data/routing_policy_gate.dart';

/// Whether the Routing page's switches and Custom rules act on [server].
/// False for a server whose config brings a routing of its own (a provider's):
/// the app leaves that config's rules alone. True with no server chosen, so
/// the page has nothing to warn about yet.
bool routingAppliesTo(VpnServer? server) =>
    server == null || !RoutingPolicyGate.ownsRouting(server.configJson);
