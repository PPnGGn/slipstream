import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/features/subscriptions/data/server_problem.dart';

/// The short note on a server's row.
String serverProblemLabel(ServerProblem problem) => switch (problem) {
  ServerProblem.realityWithoutKey => 'No REALITY key',
};

/// What a tap says about a server that cannot connect.
ToastSpec serverProblemToast(ServerProblem problem) => switch (problem) {
  ServerProblem.realityWithoutKey => const ToastSpec(
    "This server can't connect",
    subtitle: 'NO REALITY KEY IN THE SUBSCRIPTION',
    kind: ToastKind.error,
  ),
};

/// The toast for a tap on [server]'s row; null when it is fine.
ToastSpec? serverTapToast(VpnServer server) {
  final problem = serverProblem(server);
  return problem == null ? null : serverProblemToast(problem);
}
