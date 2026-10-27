import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/core/ui/toast/show_toast.dart';

bool isTunnelActive(VpnState state) => state.maybeWhen(
  connected: (_, _, _, _) => true,
  connecting: () => true,
  orElse: () => false,
);

/// A setting changed while the tunnel runs: the new value reaches the core
/// only on the next connect, so the user is told. Null when nothing runs.
ToastSpec? reconnectHintToast(VpnState state) => isTunnelActive(state)
    ? const ToastSpec(
        'Applies on reconnect',
        subtitle: 'RECONNECT TO USE NEW SETTINGS',
        kind: ToastKind.info,
      )
    : null;

void notifyIfTunnelActive(VpnServiceCubit vpn) {
  final hint = reconnectHintToast(vpn.state);
  if (hint != null) showToastSpec(hint);
}
