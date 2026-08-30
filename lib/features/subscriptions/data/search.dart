import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/subscriptions/data/vpn_server_display.dart';

List<VpnServer> filterServers(List<VpnServer> servers, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return servers;
  return servers
      .where(
        (s) =>
            s.title.toLowerCase().contains(normalized) ||
            s.countryCode.toLowerCase().contains(normalized) ||
            (s.meta.protocol?.toLowerCase().contains(normalized) ?? false),
      )
      .toList();
}
