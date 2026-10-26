import 'package:slipstream/features/split_tunnel/data/split_tunnel_mode.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_settings.dart';

String splitTunnelSummary(SplitTunnelSettings settings) {
  if (!settings.enabled) return 'Off';
  if (settings.packages.isEmpty) return 'No apps selected';
  final mode = switch (settings.mode) {
    SplitTunnelMode.proxy => 'Proxy',
    SplitTunnelMode.bypass => 'Bypass',
  };
  final count = settings.packages.length;
  return '$mode · $count ${count == 1 ? 'app' : 'apps'}';
}
