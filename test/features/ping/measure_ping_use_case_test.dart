import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/ping/domain/contracts/host_resolver.dart';
import 'package:slipstream/features/ping/domain/contracts/server_pinger.dart';
import 'package:slipstream/features/ping/domain/entities/ping_attempt_result.dart';
import 'package:slipstream/features/ping/domain/entities/ping_round_result.dart';
import 'package:slipstream/features/ping/domain/entities/ping_target.dart';
import 'package:slipstream/features/ping/domain/usecases/measure_ping_use_case.dart';

/// Scripted pinger: answers per call index, records which resolved
/// address each attempt was made against.
class _FakePinger implements ServerPinger {
  _FakePinger(this._script);

  final PingAttemptResult Function(int callIndex) _script;
  final addressesUsed = <InternetAddress>[];

  @override
  Future<PingAttemptResult> ping({
    required PingTarget target,
    required InternetAddress address,
    required Duration timeout,
  }) async {
    addressesUsed.add(address);
    return _script(addressesUsed.length - 1);
  }
}

class _FakeResolver implements HostResolver {
  _FakeResolver(this.addresses);

  final List<InternetAddress> addresses;

  @override
  Future<List<InternetAddress>> resolve(String host) async => addresses;
}

class _EmptyResolver implements HostResolver {
  const _EmptyResolver();

  @override
  Future<List<InternetAddress>> resolve(String host) async => const [];
}

final _addr1 = InternetAddress('10.0.0.1');
final _addr2 = InternetAddress('10.0.0.2');

const _target = PingTarget(host: 'example.com', port: 443, probe: PingProbe.tcp);

void main() {
  group('MeasurePingUseCase', () {
    test('measured round: 3 successes reduce to their median', () async {
      final pinger = _FakePinger(
        (i) => PingAttemptSuccess(<double>[100, 300, 200][i]),
      );
      final useCase = MeasurePingUseCase(
        pinger,
        pinger,
        _FakeResolver([_addr1]),
      );

      final result = await useCase.measure(_target);

      expect(result.status, PingRoundStatus.measured);
      expect(result.attemptCount, 3);
      expect(result.successCount, 3);
      expect(result.latencyMs, 200);
    });

    test('two consecutive failures stop the round early', () async {
      final pinger = _FakePinger((_) => const PingAttemptTimedOut());
      final useCase = MeasurePingUseCase(
        pinger,
        pinger,
        _FakeResolver([_addr1]),
      );

      final result = await useCase.measure(_target);

      expect(result.status, PingRoundStatus.unreachable);
      expect(result.successCount, 0);
      // Stops after maxConsecutiveFailures (2), not maxAttempts (3):
      // no point spending the third attempt on an already-dead round.
      expect(result.attemptCount, 2);
      expect(result.failureReason, PingFailureReason.timeout);
    });

    test('a refusal is reported distinctly from a timeout', () async {
      final pinger = _FakePinger((_) => const PingAttemptRefused());
      final useCase = MeasurePingUseCase(
        pinger,
        pinger,
        _FakeResolver([_addr1]),
      );

      final result = await useCase.measure(_target);

      expect(result.failureReason, PingFailureReason.refused);
    });

    test(
      'a lone failure does not stop the round: only successes reach the median',
      () async {
        final pinger = _FakePinger(
          (i) => switch (i) {
            0 => const PingAttemptSuccess(100),
            1 => const PingAttemptTimedOut(),
            _ => const PingAttemptSuccess(300),
          },
        );
        final useCase = MeasurePingUseCase(
          pinger,
          pinger,
          _FakeResolver([_addr1]),
        );

        final result = await useCase.measure(_target);

        expect(result.status, PingRoundStatus.measured);
        expect(result.attemptCount, 3);
        expect(result.successCount, 2);
        expect(result.latencyMs, 200); // median of [100, 300]
      },
    );

    test('rotates through every resolved address across attempts', () async {
      final pinger = _FakePinger((_) => const PingAttemptTimedOut());
      final useCase = MeasurePingUseCase(
        pinger,
        pinger,
        _FakeResolver([_addr1, _addr2]),
      );

      await useCase.measure(_target);

      expect(pinger.addressesUsed, [_addr1, _addr2]);
    });

    test('DNS failure is reported without any probe attempt', () async {
      final pinger = _FakePinger((_) => const PingAttemptSuccess(1));
      final useCase = MeasurePingUseCase(pinger, pinger, const _EmptyResolver());

      final result = await useCase.measure(_target);

      expect(result.status, PingRoundStatus.unreachable);
      expect(result.attemptCount, 0);
      expect(result.failureReason, PingFailureReason.dns);
      expect(pinger.addressesUsed, isEmpty);
    });
  });
}
