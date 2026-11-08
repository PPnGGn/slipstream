import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/core/ui/toast/show_toast.dart';
import 'package:slipstream/l10n/l10n_context.dart';

bool isTunnelActive(VpnState state) => state.maybeWhen(
  connected: (_, _, _, _) => true,
  connecting: () => true,
  orElse: () => false,
);

/// A setting changed while the tunnel runs: the new value reaches the core
/// only on the next connect, so the user is told. Null when nothing runs.
ToastSpec? reconnectHintToast(AppLocalizations l10n, VpnState state) =>
    isTunnelActive(state)
    ? ToastSpec(
        l10n.reconnectToastTitle,
        subtitle: l10n.reconnectToastHint,
        kind: ToastKind.info,
      )
    : null;

void notifyIfTunnelActive(AppLocalizations l10n, VpnServiceCubit vpn) {
  final hint = reconnectHintToast(l10n, vpn.state);
  if (hint != null) showToastSpec(hint);
}
