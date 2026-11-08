import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/core/ui/toast/show_toast.dart';
import 'package:slipstream/features/subscriptions/ui/server_problem_view.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// What a tap on the connect ring / bar says when it cannot start anything:
/// no server is picked, or the picked one cannot connect. Null when the tap
/// does its job (starts or stops the tunnel) or cannot do anything until the
/// current change is over.
ToastSpec? connectTapToast({
  required AppLocalizations l10n,
  required VpnState state,
  required VpnServer? server,
  required bool hasSubscriptions,
}) {
  final startsTunnel = state.maybeWhen(
    disconnected: () => true,
    error: (_) => true,
    orElse: () => false,
  );
  if (!startsTunnel) return null;
  if (server != null) return serverTapToast(l10n, server);

  return ToastSpec(
    l10n.connectNoServerTitle,
    subtitle: hasSubscriptions
        ? l10n.connectPickHint
        : l10n.connectAddFirstHint,
    kind: ToastKind.error,
  );
}

/// The tap handler of both home layouts: toggles the tunnel, or says why it
/// cannot.
Future<void> handleConnectTap(
  VpnServiceCubit vpn, {
  required AppLocalizations l10n,
  required VpnServer? server,
  required bool hasSubscriptions,
}) async {
  final toast = connectTapToast(
    l10n: l10n,
    state: vpn.state,
    server: server,
    hasSubscriptions: hasSubscriptions,
  );
  if (toast != null) {
    showToastSpec(toast);
    return;
  }
  await vpn.toggle(server);
}
