import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/vpn/presentation/connect_tap.dart';

const _server = VpnServer(
  id: 'ams',
  subscriptionId: 'sub',
  countryCode: 'NL',
  title: 'Amsterdam',
  configJson: '{}',
);

void main() {
  const pickOne = ToastSpec(
    'No server selected',
    subtitle: 'PICK A SERVER FROM THE LIST',
    kind: ToastKind.error,
  );
  const addFirst = ToastSpec(
    'No server selected',
    subtitle: 'ADD A SUBSCRIPTION FIRST',
    kind: ToastKind.error,
  );

  group('connectTapToast', () {
    test('with subscriptions it asks to pick a server', () {
      expect(
        connectTapToast(
          state: const VpnState.disconnected(),
          server: null,
          hasSubscriptions: true,
        ),
        pickOne,
      );
    });

    test('with none it asks to add a subscription first', () {
      expect(
        connectTapToast(
          state: const VpnState.disconnected(),
          server: null,
          hasSubscriptions: false,
        ),
        addFirst,
      );
    });

    test('after a failed attempt the same applies', () {
      expect(
        connectTapToast(
          state: const VpnState.error('boom'),
          server: null,
          hasSubscriptions: true,
        ),
        pickOne,
      );
    });

    test('with a server there is nothing to say', () {
      expect(
        connectTapToast(
          state: const VpnState.disconnected(),
          server: _server,
          hasSubscriptions: true,
        ),
        isNull,
      );
    });

    test('a tap that turns the tunnel off needs no server', () {
      expect(
        connectTapToast(
          state: VpnState.connected(_server, connectedAt: DateTime(2026)),
          server: null,
          hasSubscriptions: true,
        ),
        isNull,
      );
      expect(
        connectTapToast(
          state: const VpnState.connecting(),
          server: null,
          hasSubscriptions: true,
        ),
        isNull,
      );
    });

    test('while it is disconnecting a tap does nothing, silently', () {
      expect(
        connectTapToast(
          state: const VpnState.disconnecting(),
          server: null,
          hasSubscriptions: true,
        ),
        isNull,
      );
    });
  });
}
