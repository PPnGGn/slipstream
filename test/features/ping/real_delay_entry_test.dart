import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/ping/presentation/real_delay_entry.dart';

void main() {
  group('realDelayTierOf', () {
    test('below 300 ms is good', () {
      expect(realDelayTierOf(0), RealDelayTier.good);
      expect(realDelayTierOf(299), RealDelayTier.good);
    });

    test('300 to 700 ms inclusive is medium', () {
      expect(realDelayTierOf(300), RealDelayTier.medium);
      expect(realDelayTierOf(700), RealDelayTier.medium);
    });

    test('above 700 ms is poor', () {
      expect(realDelayTierOf(701), RealDelayTier.poor);
      expect(realDelayTierOf(7000), RealDelayTier.poor);
    });
  });

  group('RealDelayEntry', () {
    test('a server nobody measured is not tested and has no number', () {
      const entry = RealDelayEntry.notTested();

      expect(entry.status, RealDelayStatus.notTested);
      expect(entry.latencyMs, isNull);
      expect(entry.failure, isNull);
    });

    test('a measured one carries the milliseconds', () {
      const entry = RealDelayEntry.measured(412);

      expect(entry.status, RealDelayStatus.measured);
      expect(entry.latencyMs, 412);
    });

    test('a failed one says why', () {
      const entry = RealDelayEntry.failed(RealDelayFailure.timeout);

      expect(entry.status, RealDelayStatus.failed);
      expect(entry.failure, RealDelayFailure.timeout);
      expect(entry.latencyMs, isNull);
    });
  });
}
