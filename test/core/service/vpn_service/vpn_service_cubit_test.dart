import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';
import 'package:slipstream/features/vpn/data/vpn_repository.dart';
import 'package:slipstream/features/vpn/data/vpn_session_store.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Only what the cubit calls. A Fake throws on anything else, so a new
/// dependency of the cubit shows up here instead of passing unnoticed.
class _FakeRepository extends Fake implements VpnRepository {
  final statusController = StreamController<VpnStatusMessage>.broadcast();
  var startCalls = 0;
  var stopCalls = 0;

  @override
  Stream<VpnStatusMessage> get status => statusController.stream;

  @override
  Stream<VpnTrafficMessage> get traffic => const Stream.empty();

  /// What getStatus answers; a test swaps it to hold or break the first read.
  Future<VpnStatusMessage> Function() onGetStatus = () async =>
      VpnStatusMessage(status: VpnStatus.disconnected);

  @override
  Future<VpnStatusMessage> getStatus() => onGetStatus();

  @override
  Future<Result<void>> start(VpnServer server) async {
    startCalls++;
    return const Success(null);
  }

  @override
  Future<Result<void>> stop() async {
    stopCalls++;
    return const Success(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const amsterdam = VpnServer(
    id: 'ams',
    subscriptionId: 'nebula',
    countryCode: 'NL',
    title: 'Amsterdam',
    configJson: '{}',
  );

  late _FakeRepository repository;
  late VpnServiceCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = _FakeRepository();
    cubit = VpnServiceCubit(
      repository: repository,
      sessionStore: VpnSessionStore(await SharedPreferences.getInstance()),
      talker: Talker(),
    );
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);
  });

  Future<void> native(VpnStatus status, {String? error}) async {
    repository.statusController.add(
      VpnStatusMessage(status: status, error: error),
    );
    await Future<void>.delayed(Duration.zero);
  }

  group('firstSync', () {
    // A cubit whose first status read the test controls.
    Future<VpnServiceCubit> built(_FakeRepository repo) async {
      final c = VpnServiceCubit(
        repository: repo,
        sessionStore: VpnSessionStore(await SharedPreferences.getInstance()),
        talker: Talker(),
      );
      addTearDown(c.close);
      return c;
    }

    test('is not done until the first native status is read', () async {
      final gate = Completer<VpnStatusMessage>();
      final repo = _FakeRepository()..onGetStatus = () => gate.future;
      final c = await built(repo);

      var done = false;
      unawaited(c.firstSync.then((_) => done = true));
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse, reason: 'the state is still the initial guess');

      gate.complete(VpnStatusMessage(status: VpnStatus.blocked, error: 'x'));
      await c.firstSync;

      expect(c.state, const VpnState.blocked('x'));
    });

    test('is done even when the status cannot be read', () async {
      final repo = _FakeRepository()
        ..onGetStatus = () async => throw StateError('no bridge');
      final c = await built(repo);

      await c.firstSync.timeout(const Duration(seconds: 2));

      expect(c.state, const VpnState.disconnected());
    });

    test('later reads do not make it a different future', () async {
      final c = await built(_FakeRepository());
      await c.firstSync;

      // Coming back to the app reads the status again.
      await c.firstSync;

      expect(c.state, const VpnState.disconnected());
    });
  });

  group('blocked', () {
    test('the native blocked status becomes the blocked state', () async {
      await native(VpnStatus.blocked, error: 'Connection lost');

      expect(cubit.state, const VpnState.blocked('Connection lost'));
    });

    test('a blocked status without a reason still says something', () async {
      await native(VpnStatus.blocked);

      expect(cubit.state, isA<VpnState>().having(
        (s) => s.maybeWhen(blocked: (m) => m, orElse: () => null),
        'message',
        isNotEmpty,
      ));
    });

    test('toggle while blocked turns the VPN off', () async {
      await native(VpnStatus.blocked, error: 'x');

      await cubit.toggle(amsterdam);

      expect(repository.stopCalls, 1);
      expect(repository.startCalls, 0);
      expect(cubit.state, const VpnState.disconnecting());
    });

    test('connect while blocked starts at once, without a stop', () async {
      await native(VpnStatus.blocked, error: 'x');

      await cubit.connect(amsterdam);

      // A stop first would drop the blocking interface and open the traffic.
      expect(repository.stopCalls, 0);
      expect(repository.startCalls, 1);
      expect(cubit.state, const VpnState.connecting());
    });

    test('switching the server counts blocked as active', () async {
      await native(VpnStatus.blocked, error: 'x');

      cubit.switchServerIfActive(amsterdam);
      await Future<void>.delayed(Duration.zero);

      expect(repository.startCalls, 1);
    });

    test('turning the VPN off from blocked ends in disconnected', () async {
      await native(VpnStatus.blocked, error: 'x');
      await cubit.disconnect();

      await native(VpnStatus.disconnected);

      expect(cubit.state, const VpnState.disconnected());
    });

    test('a working tunnel after blocked is connected', () async {
      await native(VpnStatus.blocked, error: 'x');
      await cubit.connect(amsterdam);

      await native(VpnStatus.connected);

      expect(cubit.state, isA<VpnState>().having(
        (s) => s.maybeWhen(connected: (_, _, _, _) => true, orElse: () => false),
        'connected',
        isTrue,
      ));
    });
  });
}
