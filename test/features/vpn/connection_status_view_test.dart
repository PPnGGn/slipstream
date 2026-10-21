import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/vpn/presentation/connection_status_view.dart';

void main() {
  const amsterdam = VpnServer(
    id: 'ams',
    subscriptionId: 'nebula',
    countryCode: 'NL',
    title: '🇳🇱 Amsterdam',
    configJson: '{}',
  );
  const frankfurt = VpnServer(
    id: 'fra',
    subscriptionId: 'nebula',
    countryCode: 'DE',
    title: 'Frankfurt',
    configJson: '{}',
  );

  ConnectionStatusView view(
    VpnState state, {
    bool hasSubscriptions = true,
    VpnServer? selected,
  }) => ConnectionStatusView.from(
    state: state,
    hasSubscriptions: hasSubscriptions,
    selectedServer: selected,
  );

  group('disconnected', () {
    test('without subscriptions asks to add one', () {
      final v = view(const VpnState.disconnected(), hasSubscriptions: false);
      expect(v.phase, ConnectionPhase.off);
      expect(v.title, 'No servers yet');
      expect(v.subtitle, 'Add a subscription below');
      expect(v.server, isNull);
      expect(v.compactLabel, 'off');
    });

    test('without a selection asks to pick a server', () {
      final v = view(const VpnState.disconnected());
      expect(v.title, 'Pick a server');
      expect(v.subtitle, 'Choose one from the list below');
      expect(v.server, isNull);
    });

    test('with a selection is ready to connect', () {
      final v = view(const VpnState.disconnected(), selected: amsterdam);
      expect(v.title, 'Ready to connect');
      expect(v.subtitle, 'Tap the ring to start');
      expect(v.server, amsterdam);
    });
  });

  test('connecting names the selected server without its flag', () {
    final v = view(const VpnState.connecting(), selected: amsterdam);
    expect(v.phase, ConnectionPhase.busy);
    expect(v.title, 'Establishing tunnel…');
    expect(v.subtitle, 'Amsterdam');
    expect(v.compactLabel, 'connecting…');
  });

  test('disconnecting is busy too', () {
    final v = view(const VpnState.disconnecting(), selected: amsterdam);
    expect(v.phase, ConnectionPhase.busy);
    expect(v.title, 'Disconnecting…');
    expect(v.compactLabel, 'disconnecting…');
  });

  test('connected shows the connected server, not the selection', () {
    final v = view(
      VpnState.connected(amsterdam, connectedAt: DateTime(2026, 10, 22)),
      selected: frankfurt,
    );
    expect(v.phase, ConnectionPhase.on);
    expect(v.title, 'Connected');
    expect(v.subtitle, 'Amsterdam');
    expect(v.server, amsterdam);
    expect(v.compactLabel, isNull, reason: 'the bar shows the live timer');
  });

  test('error shows the message', () {
    final v = view(
      const VpnState.error('Handshake timed out'),
      selected: amsterdam,
    );
    expect(v.phase, ConnectionPhase.error);
    expect(v.title, 'Connection failed');
    expect(v.subtitle, 'Handshake timed out');
    expect(v.server, amsterdam);
    expect(v.compactLabel, 'failed');
  });
}
