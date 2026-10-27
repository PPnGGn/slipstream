import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/settings/ui/widgets/reconnect_hint.dart';

void main() {
  const server = VpnServer(
    id: 'ams',
    subscriptionId: 'sub',
    countryCode: 'NL',
    title: 'Amsterdam',
    configJson: '{}',
  );

  test('connecting and connected need a reconnect to apply changes', () {
    expect(isTunnelActive(const VpnState.connecting()), isTrue);
    expect(
      isTunnelActive(VpnState.connected(server, connectedAt: DateTime(2026))),
      isTrue,
    );
  });

  test('every other state applies changes on the next connect anyway', () {
    expect(isTunnelActive(const VpnState.disconnected()), isFalse);
    expect(isTunnelActive(const VpnState.disconnecting()), isFalse);
    expect(isTunnelActive(const VpnState.error('x')), isFalse);
  });

  test('a running tunnel gets a hint that the change waits for reconnect', () {
    const hint = ToastSpec(
      'Applies on reconnect',
      subtitle: 'RECONNECT TO USE NEW SETTINGS',
      kind: ToastKind.info,
    );

    expect(reconnectHintToast(const VpnState.connecting()), hint);
    expect(
      reconnectHintToast(
        VpnState.connected(server, connectedAt: DateTime(2026)),
      ),
      hint,
    );
  });

  test('without a running tunnel there is nothing to say', () {
    expect(reconnectHintToast(const VpnState.disconnected()), isNull);
    expect(reconnectHintToast(const VpnState.disconnecting()), isNull);
    expect(reconnectHintToast(const VpnState.error('x')), isNull);
  });
}
