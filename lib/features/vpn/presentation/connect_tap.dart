import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/core/ui/toast/show_toast.dart';

/// What a tap on the connect ring / bar says when it cannot start anything:
/// no server is picked. Null when the tap does its job (starts or stops the
/// tunnel) or cannot do anything until the current change is over.
ToastSpec? connectTapToast({
  required VpnState state,
  required VpnServer? server,
  required bool hasSubscriptions,
}) {
  final startsTunnel = state.maybeWhen(
    disconnected: () => true,
    error: (_) => true,
    orElse: () => false,
  );
  if (server != null || !startsTunnel) return null;

  return ToastSpec(
    'No server selected',
    subtitle: hasSubscriptions
        ? 'PICK A SERVER FROM THE LIST'
        : 'ADD A SUBSCRIPTION FIRST',
    kind: ToastKind.error,
  );
}

/// The tap handler of both home layouts: toggles the tunnel, or says why it
/// cannot.
Future<void> handleConnectTap(
  VpnServiceCubit vpn, {
  required VpnServer? server,
  required bool hasSubscriptions,
}) async {
  final toast = connectTapToast(
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
