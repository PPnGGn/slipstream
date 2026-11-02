import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/auto_connect/data/auto_connect_support.dart';
import 'package:slipstream/features/auto_connect/presentation/auto_connect_decision.dart';
import 'package:slipstream/features/auto_connect/ui/auto_connect_labels.dart';

import '../subscriptions/reality_fixtures.dart';

void main() {
  const amsterdam = VpnServer(
    id: 'ams',
    subscriptionId: 'nebula',
    countryCode: 'NL',
    title: 'Amsterdam',
    configJson: '{}',
  );

  group('isAutoConnectSupported', () {
    test('is Android only', () {
      expect(isAutoConnectSupported(TargetPlatform.android), isTrue);
      expect(isAutoConnectSupported(TargetPlatform.iOS), isFalse);
      expect(isAutoConnectSupported(TargetPlatform.windows), isFalse);
      expect(isAutoConnectSupported(TargetPlatform.macOS), isFalse);
    });
  });

  group('autoConnectServer', () {
    VpnServer? decide({
      bool enabled = true,
      bool permissionGranted = true,
      VpnState vpnState = const VpnState.disconnected(),
      VpnServer? selected = amsterdam,
    }) => autoConnectServer(
      enabled: enabled,
      permissionGranted: permissionGranted,
      vpnState: vpnState,
      selectedServer: selected,
    );

    test('connects to the selected server when everything allows it', () {
      expect(decide(), amsterdam);
    });

    test('does nothing when the setting is off', () {
      expect(decide(enabled: false), isNull);
    });

    test('does nothing without the VPN permission', () {
      // Asking now would pop the system dialog at launch, or take the tunnel
      // from another VPN app.
      expect(decide(permissionGranted: false), isNull);
    });

    test('does nothing when the selected server cannot connect', () {
      // An old selection may point at a server the provider sent without its
      // key: starting it would fail in the core.
      expect(decide(selected: realityServerWithoutKey()), isNull);
    });

    test('does nothing without a selected server', () {
      expect(decide(selected: null), isNull);
    });

    test('leaves a VPN that already runs alone', () {
      // Started from the tile before the app opened: a second start would
      // tear the first one down.
      expect(
        decide(
          vpnState: VpnState.connected(amsterdam, connectedAt: DateTime(0)),
        ),
        isNull,
      );
      expect(decide(vpnState: const VpnState.connecting()), isNull);
      expect(decide(vpnState: const VpnState.disconnecting()), isNull);
    });

    test('leaves the kill switch hold alone', () {
      expect(decide(vpnState: const VpnState.blocked('x')), isNull);
    });

    test('tries again after a failed earlier attempt', () {
      expect(decide(vpnState: const VpnState.error('x')), amsterdam);
    });
  });

  group('autoConnectSubtitle', () {
    test('on: says what happens at launch', () {
      expect(
        autoConnectSubtitle(enabled: true),
        'Connects to the selected server when the app opens',
      );
    });

    test('off: says how to connect instead', () {
      expect(autoConnectSubtitle(enabled: false), 'Off · tap the ring to connect');
    });
  });
}
