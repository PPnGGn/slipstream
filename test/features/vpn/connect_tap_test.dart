import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/subscriptions/data/server_problem.dart';
import 'package:slipstream/features/subscriptions/ui/server_problem_view.dart';
import 'package:slipstream/features/vpn/presentation/connect_tap.dart';

import '../../helpers/l10n.dart';
import '../subscriptions/reality_fixtures.dart';

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
          l10n: l10nEn,
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
          l10n: l10nEn,
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
          l10n: l10nEn,
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
          l10n: l10nEn,
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
          l10n: l10nEn,
          state: VpnState.connected(_server, connectedAt: DateTime(2026)),
          server: null,
          hasSubscriptions: true,
        ),
        isNull,
      );
      expect(
        connectTapToast(
          l10n: l10nEn,
          state: const VpnState.connecting(),
          server: null,
          hasSubscriptions: true,
        ),
        isNull,
      );
    });

    test('a server that cannot connect says so instead of trying', () {
      expect(
        connectTapToast(
          l10n: l10nEn,
          state: const VpnState.disconnected(),
          server: realityServerWithoutKey(),
          hasSubscriptions: true,
        ),
        serverProblemToast(l10nEn, ServerProblem.realityWithoutKey),
      );
    });

    test('a tap that turns the tunnel off does not care about the server', () {
      // The tunnel runs on another server; the selection is broken. Turning it
      // off must still work.
      expect(
        connectTapToast(
          l10n: l10nEn,
          state: VpnState.connected(_server, connectedAt: DateTime(2026)),
          server: realityServerWithoutKey(),
          hasSubscriptions: true,
        ),
        isNull,
      );
      expect(
        connectTapToast(
          l10n: l10nEn,
          state: const VpnState.blocked('x'),
          server: realityServerWithoutKey(),
          hasSubscriptions: true,
        ),
        isNull,
      );
    });

    test('while it is disconnecting a tap does nothing, silently', () {
      expect(
        connectTapToast(
          l10n: l10nEn,
          state: const VpnState.disconnecting(),
          server: null,
          hasSubscriptions: true,
        ),
        isNull,
      );
    });
  });
}
