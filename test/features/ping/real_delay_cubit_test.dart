import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/ping/data/real_delay_client.dart';
import 'package:slipstream/features/ping/presentation/real_delay_cubit.dart';
import 'package:slipstream/features/ping/presentation/real_delay_entry.dart';

/// Answers the n-th call with the n-th of [answers].
class _FakeClient implements RealDelayClient {
  _FakeClient(this.answers);

  final List<Future<RealDelayOutcome>> answers;
  final measured = <String>[];

  @override
  Future<RealDelayOutcome> measure(VpnServer server) {
    measured.add(server.id);
    return answers[measured.length - 1];
  }
}

VpnServer _server(String id, {String config = '{"outbounds": []}'}) =>
    VpnServer(
      id: id,
      subscriptionId: 's',
      countryCode: 'NL',
      title: id,
      configJson: config,
    );

// A REALITY server whose config has no key: serverProblem says it cannot work.
final _broken = _server(
  'broken',
  config:
      '{"outbounds":[{"tag":"proxy","streamSettings":{"security":"reality","realitySettings":{}}}]}',
);

Future<RealDelayOutcome> _ms(int ms) async => RealDelayOutcome.measured(ms);

void main() {
  test('a server nobody measured has no entry yet', () {
    final cubit = RealDelayCubit(_FakeClient([]));

    expect(cubit.state.of('a').status, RealDelayStatus.notTested);
  });

  test('a measurement shows measuring first, then the number', () async {
    final answer = Completer<RealDelayOutcome>();
    final cubit = RealDelayCubit(_FakeClient([answer.future]));
    final seen = <RealDelayStatus>[];
    cubit.stream.listen((s) => seen.add(s.of('a').status));

    final done = cubit.measure(_server('a'));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.of('a').status, RealDelayStatus.measuring);
    expect(cubit.state.busy, isTrue);

    answer.complete(const RealDelayOutcome.measured(240));
    await done;

    expect(cubit.state.of('a').status, RealDelayStatus.measured);
    expect(cubit.state.of('a').latencyMs, 240);
    expect(cubit.state.busy, isFalse);
    await Future<void>.delayed(
      Duration.zero,
    ); // the stream delivers a tick later
    expect(seen, [RealDelayStatus.measuring, RealDelayStatus.measured]);
  });

  test('a failure is kept with its kind', () async {
    final cubit = RealDelayCubit(
      _FakeClient([
        Future.value(const RealDelayOutcome.failed(RealDelayFailure.timeout)),
      ]),
    );

    await cubit.measure(_server('a'));

    expect(cubit.state.of('a').status, RealDelayStatus.failed);
    expect(cubit.state.of('a').failure, RealDelayFailure.timeout);
  });

  test('a client that throws is a failure, not a crash', () async {
    final cubit = RealDelayCubit(
      _FakeClient([Future.error(StateError('bridge is gone'))]),
    );

    await cubit.measure(_server('a'));

    expect(cubit.state.of('a').status, RealDelayStatus.failed);
    expect(cubit.state.of('a').failure, RealDelayFailure.other);
  });

  test('a second tap while one measurement runs is ignored', () async {
    final answer = Completer<RealDelayOutcome>();
    final client = _FakeClient([answer.future, _ms(100)]);
    final cubit = RealDelayCubit(client);

    final first = cubit.measure(_server('a'));
    await Future<void>.delayed(Duration.zero);
    await cubit.measure(_server('a'));
    await cubit.measure(_server('b'));

    expect(client.measured, ['a']);
    expect(cubit.state.of('b').status, RealDelayStatus.notTested);

    answer.complete(const RealDelayOutcome.measured(1));
    await first;
  });

  test('after one measurement is over the next one starts', () async {
    final client = _FakeClient([_ms(100), _ms(200)]);
    final cubit = RealDelayCubit(client);

    await cubit.measure(_server('a'));
    await cubit.measure(_server('b'));

    expect(client.measured, ['a', 'b']);
    expect(cubit.state.of('a').latencyMs, 100);
    expect(cubit.state.of('b').latencyMs, 200);
  });

  test('a new measurement of a server replaces its old number', () async {
    final cubit = RealDelayCubit(_FakeClient([_ms(100), _ms(500)]));

    await cubit.measure(_server('a'));
    await cubit.measure(_server('a'));

    expect(cubit.state.of('a').latencyMs, 500);
  });

  test('a server that cannot work is not measured', () async {
    final client = _FakeClient([_ms(1)]);
    final cubit = RealDelayCubit(client);

    await cubit.measure(_broken);

    expect(client.measured, isEmpty);
    expect(cubit.state.of('broken').status, RealDelayStatus.notTested);
  });
}
