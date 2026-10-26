import 'package:slipstream/features/split_tunnel/data/split_tunnel_mode.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_settings.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';

({VpnSplitMode? mode, List<String>? packages}) splitTunnelMessage(
  SplitTunnelSettings settings,
) {
  if (!settings.isActive) return (mode: null, packages: null);
  return (
    mode: switch (settings.mode) {
      SplitTunnelMode.proxy => VpnSplitMode.proxy,
      SplitTunnelMode.bypass => VpnSplitMode.bypass,
    },
    packages: settings.packages.toList()..sort(),
  );
}
