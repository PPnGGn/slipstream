import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/features/subscriptions/data/server_problem.dart';
import 'package:slipstream/features/subscriptions/ui/server_problem_view.dart';

import 'reality_fixtures.dart';

void main() {
  test('the row label names the missing key', () {
    expect(
      serverProblemLabel(ServerProblem.realityWithoutKey),
      'No REALITY key',
    );
  });

  test('the toast says the server cannot connect and why', () {
    expect(
      serverProblemToast(ServerProblem.realityWithoutKey),
      const ToastSpec(
        "This server can't connect",
        subtitle: 'NO REALITY KEY IN THE SUBSCRIPTION',
        kind: ToastKind.error,
      ),
    );
  });

  group('serverTapToast', () {
    test('a server with a problem gets the toast', () {
      expect(
        serverTapToast(realityServerWithoutKey()),
        serverProblemToast(ServerProblem.realityWithoutKey),
      );
    });

    test('a working server gets none', () {
      expect(serverTapToast(realityServerWithKey()), isNull);
    });
  });
}
