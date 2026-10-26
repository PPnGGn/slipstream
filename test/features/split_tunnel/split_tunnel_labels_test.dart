import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_mode.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_settings.dart';
import 'package:slipstream/features/split_tunnel/ui/split_tunnel_labels.dart';

void main() {
  test('off', () {
    expect(splitTunnelSummary(const SplitTunnelSettings()), 'Off');
  });

  test('off even with apps picked', () {
    const settings = SplitTunnelSettings(packages: {'a'});
    expect(splitTunnelSummary(settings), 'Off');
  });

  test('on with nothing picked says so', () {
    const settings = SplitTunnelSettings(enabled: true);
    expect(splitTunnelSummary(settings), 'No apps selected');
  });

  test('bypass with one app', () {
    const settings = SplitTunnelSettings(enabled: true, packages: {'a'});
    expect(splitTunnelSummary(settings), 'Bypass · 1 app');
  });

  test('proxy with several apps', () {
    const settings = SplitTunnelSettings(
      enabled: true,
      mode: SplitTunnelMode.proxy,
      packages: {'a', 'b', 'c'},
    );
    expect(splitTunnelSummary(settings), 'Proxy · 3 apps');
  });
}
