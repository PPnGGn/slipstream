import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/launch_sync/data/launch_sync_decision.dart';

import '../subscriptions/reality_fixtures.dart';

void main() {
  const amsterdam = VpnServer(
    id: 'ams',
    subscriptionId: 'nebula',
    countryCode: 'NL',
    title: 'Amsterdam',
    configJson: '{}',
  );

  group('isLaunchSyncSupported', () {
    test('is Android only: the saved launch is the tile\'s', () {
      expect(isLaunchSyncSupported(TargetPlatform.android), isTrue);
      expect(isLaunchSyncSupported(TargetPlatform.iOS), isFalse);
      expect(isLaunchSyncSupported(TargetPlatform.windows), isFalse);
      expect(isLaunchSyncSupported(TargetPlatform.macOS), isFalse);
    });
  });

  group('isLaunchSavable', () {
    test('only while nothing runs', () {
      expect(isLaunchSavable(const VpnState.disconnected()), isTrue);
      // A failed attempt may have been a bad moment, not a bad server.
      expect(isLaunchSavable(const VpnState.error('x')), isTrue);
    });

    test('never while the tunnel is up, coming up, going down or held', () {
      // A restart of the service reads the saved launch: overwriting it under
      // a running session would bring back a different server than the one
      // that was up.
      expect(
        isLaunchSavable(
          VpnState.connected(amsterdam, connectedAt: DateTime(0)),
        ),
        isFalse,
      );
      expect(isLaunchSavable(const VpnState.connecting()), isFalse);
      expect(isLaunchSavable(const VpnState.disconnecting()), isFalse);
      expect(isLaunchSavable(const VpnState.blocked('x')), isFalse);
    });
  });

  group('launchServerToSave', () {
    VpnServer? decide({
      VpnState vpnState = const VpnState.disconnected(),
      VpnServer? selected = amsterdam,
    }) => launchServerToSave(vpnState: vpnState, selectedServer: selected);

    test('the selected server, when nothing runs', () {
      expect(decide(), amsterdam);
    });

    test('nothing without a selected server', () {
      expect(decide(selected: null), isNull);
    });

    test('nothing while a session is up or on its way', () {
      expect(decide(vpnState: const VpnState.connecting()), isNull);
      expect(
        decide(
          vpnState: VpnState.connected(amsterdam, connectedAt: DateTime(0)),
        ),
        isNull,
      );
      expect(decide(vpnState: const VpnState.blocked('x')), isNull);
    });

    test('a server that cannot connect is not saved over a good launch', () {
      // The tile would only fail with it, and the previous launch still works.
      expect(decide(selected: realityServerWithoutKey()), isNull);
    });

    test('a server with a key is saved', () {
      final good = realityServerWithKey();
      expect(decide(selected: good), good);
    });
  });
}
