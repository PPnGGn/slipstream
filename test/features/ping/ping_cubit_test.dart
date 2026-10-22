import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/ping/data/ping_settings_store.dart';
import 'package:slipstream/features/ping/data/ping_target_resolver.dart';
import 'package:slipstream/features/ping/domain/contracts/host_resolver.dart';
import 'package:slipstream/features/ping/domain/contracts/server_pinger.dart';
import 'package:slipstream/features/ping/domain/entities/ping_attempt_result.dart';
import 'package:slipstream/features/ping/domain/entities/ping_target.dart';
import 'package:slipstream/features/ping/domain/usecases/measure_ping_use_case.dart';
import 'package:slipstream/features/ping/presentation/ping_cubit.dart';
import 'package:slipstream/features/ping/presentation/ping_entry.dart';

/// Targets straight from the server: host = the server's title, so tests
/// can put several servers on one host.
class _Targets extends Fake implements PingTargetResolver {
  @override
  PingTarget? resolve(VpnServer server) =>
      PingTarget(host: server.title, port: 443, probe: PingProbe.tcp);
}

class _CountingResolver implements HostResolver {
  final lookups = <String>[];

  @override
  Future<List<InternetAddress>> resolve(String host) async {
    lookups.add(host);
    return [InternetAddress('10.0.0.1')];
  }
}

/// Until [release], the first attempt per host blocks and every later one
/// answers 50 ms at once. After [release], everything answers 100 ms.
class _GatedPinger implements ServerPinger {
  final _gate = Completer<void>();
  final _seen = <String>{};

  void release() => _gate.complete();

  @override
  Future<PingAttemptResult> ping({
    required PingTarget target,
    required InternetAddress address,
    required Duration timeout,
  }) async {
    if (_gate.isCompleted) return const PingAttemptSuccess(100);
    if (_seen.add(target.host)) {
      await _gate.future;
      return const PingAttemptSuccess(100);
    }
    return const PingAttemptSuccess(50);
  }
}

class _InstantPinger implements ServerPinger {
  @override
  Future<PingAttemptResult> ping({
    required PingTarget target,
    required InternetAddress address,
    required Duration timeout,
  }) async => const PingAttemptSuccess(20);
}

VpnServer _server(String id, {String? host}) => VpnServer(
  id: id,
  subscriptionId: 'sub',
  countryCode: 'NL',
  title: host ?? id,
  configJson: '{}',
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  Future<PingCubit> cubitWith(
    ServerPinger pinger,
    HostResolver resolver,
  ) async {
    SharedPreferences.setMockInitialValues({});
    return PingCubit(
      MeasurePingUseCase(pinger, pinger, resolver),
      _Targets(),
      PingSettingsStore(await SharedPreferences.getInstance()),
    );
  }

  test('a run started mid-way leaves the earlier run to finish its other '
      'servers', () async {
    final pinger = _GatedPinger();
    final cubit = await cubitWith(pinger, _CountingResolver());
    final a = _server('a'), b = _server('b'), c = _server('c');

    final first = cubit.runForServers([a, b, c]);
    await _settle();
    final second = cubit.runForServers([c]);
    await _settle();
    pinger.release();
    await Future.wait([first, second]);

    expect(cubit.state.entries['a']?.status, PingRunStatus.measured);
    expect(cubit.state.entries['b']?.status, PingRunStatus.measured);
    expect(cubit.state.isRunning, isFalse);
  });

  test('the later run owns a server both runs measure', () async {
    final pinger = _GatedPinger();
    final cubit = await cubitWith(pinger, _CountingResolver());
    final c = _server('c');

    final first = cubit.runForServers([_server('a'), c]);
    await _settle();
    final second = cubit.runForServers([c]);
    await second;
    expect(cubit.state.entries['c']?.latencyMs, 50);

    pinger.release();
    await first;

    // The first run's late answer for c must not overwrite the newer one.
    expect(cubit.state.entries['c']?.latencyMs, 50);
    expect(cubit.state.entries['a']?.latencyMs, 100);
  });

  test('isRunning stays true until every overlapping run is done', () async {
    final pinger = _GatedPinger();
    final cubit = await cubitWith(pinger, _CountingResolver());

    final first = cubit.runForServers([_server('a')]);
    await _settle();
    final second = cubit.runForServers([_server('b', host: 'a')]);
    await second;

    expect(cubit.state.isRunning, isTrue);

    pinger.release();
    await first;
    expect(cubit.state.isRunning, isFalse);
  });

  test('servers on one host resolve it once per run', () async {
    final resolver = _CountingResolver();
    final cubit = await cubitWith(_InstantPinger(), resolver);

    await cubit.runForServers([
      _server('a', host: 'shared.example'),
      _server('b', host: 'shared.example'),
      _server('c', host: 'other.example'),
    ]);

    expect(resolver.lookups..sort(), ['other.example', 'shared.example']);
    expect(
      cubit.state.entries.values.map((e) => e.status),
      everyElement(PingRunStatus.measured),
    );
  });

  test('each run resolves again: addresses may have changed', () async {
    final resolver = _CountingResolver();
    final cubit = await cubitWith(_InstantPinger(), resolver);
    final server = _server('a', host: 'shared.example');

    await cubit.runForServers([server]);
    await cubit.runForServers([server]);

    expect(resolver.lookups, ['shared.example', 'shared.example']);
  });
}
