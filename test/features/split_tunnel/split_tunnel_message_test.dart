import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_message.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_mode.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_settings.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';

void main() {
  test('switched off sends nothing', () {
    final message = splitTunnelMessage(
      const SplitTunnelSettings(packages: {'com.a'}),
    );
    expect(message.mode, isNull);
    expect(message.packages, isNull);
  });

  test('on with an empty list sends nothing', () {
    final message = splitTunnelMessage(
      const SplitTunnelSettings(enabled: true, mode: SplitTunnelMode.proxy),
    );
    expect(message.mode, isNull);
    expect(message.packages, isNull);
  });

  test('bypass is sent with the picked packages', () {
    final message = splitTunnelMessage(
      const SplitTunnelSettings(enabled: true, packages: {'com.b', 'com.a'}),
    );
    expect(message.mode, VpnSplitMode.bypass);
    expect(message.packages, ['com.a', 'com.b']);
  });

  test('proxy is sent with the picked packages', () {
    final message = splitTunnelMessage(
      const SplitTunnelSettings(
        enabled: true,
        mode: SplitTunnelMode.proxy,
        packages: {'com.a'},
      ),
    );
    expect(message.mode, VpnSplitMode.proxy);
    expect(message.packages, ['com.a']);
  });
}
