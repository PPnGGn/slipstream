import 'package:slipstream/features/split_tunnel/data/split_tunnel_mode.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_settings.dart';

String splitTunnelHint(SplitTunnelMode mode) => switch (mode) {
  SplitTunnelMode.proxy =>
    'Only selected apps go through the tunnel; everything else connects '
        'directly.',
  SplitTunnelMode.bypass =>
    'Selected apps connect directly; everything else goes through the '
        'tunnel.',
};

String splitTunnelCounter({
  required int selected,
  required int total,
  required SplitTunnelMode mode,
}) {
  final side = mode == SplitTunnelMode.proxy ? 'proxied' : 'bypassed';
  return '$selected of $total apps $side';
}

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
