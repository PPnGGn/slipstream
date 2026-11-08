import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/features/subscriptions/data/server_problem.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// The short note on a server's row.
String serverProblemLabel(AppLocalizations l10n, ServerProblem problem) =>
    switch (problem) {
      ServerProblem.realityWithoutKey => l10n.serverProblemRealityLabel,
    };

/// What a tap says about a server that cannot connect.
ToastSpec serverProblemToast(AppLocalizations l10n, ServerProblem problem) =>
    switch (problem) {
      ServerProblem.realityWithoutKey => ToastSpec(
        l10n.serverProblemRealityTitle,
        subtitle: l10n.serverProblemRealityHint,
        kind: ToastKind.error,
      ),
    };

/// The toast for a tap on [server]'s row; null when it is fine.
ToastSpec? serverTapToast(AppLocalizations l10n, VpnServer server) {
  final problem = serverProblem(server);
  return problem == null ? null : serverProblemToast(l10n, problem);
}
