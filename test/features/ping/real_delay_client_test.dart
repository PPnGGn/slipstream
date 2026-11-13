import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/ping/data/real_delay_api.g.dart';
import 'package:slipstream/features/ping/data/real_delay_client.dart';
import 'package:slipstream/features/ping/presentation/real_delay_entry.dart';

void main() {
  group('outcomeOfResult', () {
    test('a number is a measurement', () {
      final outcome = outcomeOfResult(RealDelayResult(latencyMs: 250));

      expect(outcome.latencyMs, 250);
      expect(outcome.failure, isNull);
    });

    test('the core saying it timed out is a timeout', () {
      final outcome = outcomeOfResult(
        RealDelayResult(error: 'measure: timed out'),
      );

      expect(outcome.latencyMs, isNull);
      expect(outcome.failure, RealDelayFailure.timeout);
    });

    test('any other error is a failure of another kind', () {
      final outcome = outcomeOfResult(
        RealDelayResult(error: 'measure: the server answered 502'),
      );

      expect(outcome.failure, RealDelayFailure.other);
    });

    test('an answer with neither a number nor an error is a failure too', () {
      final outcome = outcomeOfResult(RealDelayResult());

      expect(outcome.latencyMs, isNull);
      expect(outcome.failure, RealDelayFailure.other);
    });
  });
}
