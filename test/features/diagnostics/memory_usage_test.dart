import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/diagnostics/cubit/memory_usage_cubit.dart';

void main() {
  group('computeMemoryHealth from ok', () {
    test('stays ok below the warn threshold', () {
      expect(computeMemoryHealth(0.59, MemoryHealth.ok), MemoryHealth.ok);
    });

    test('crosses into warn at the threshold', () {
      expect(computeMemoryHealth(0.60, MemoryHealth.ok), MemoryHealth.warn);
    });

    test('crosses into danger at the threshold', () {
      expect(computeMemoryHealth(0.85, MemoryHealth.ok), MemoryHealth.danger);
    });
  });

  group('computeMemoryHealth hysteresis', () {
    test('warn does not fall back to ok just below its own threshold', () {
      // 0.58 is below 0.60 but within the 0.03 hysteresis band.
      expect(computeMemoryHealth(0.58, MemoryHealth.warn), MemoryHealth.warn);
    });

    test('warn falls back to ok once clearly below the threshold', () {
      expect(computeMemoryHealth(0.56, MemoryHealth.warn), MemoryHealth.ok);
    });

    test('warn escalates to danger at its threshold', () {
      expect(computeMemoryHealth(0.85, MemoryHealth.warn), MemoryHealth.danger);
    });

    test('danger does not fall back to warn just below its own threshold', () {
      // 0.83 is below 0.85 but within the 0.03 hysteresis band.
      expect(computeMemoryHealth(0.83, MemoryHealth.danger), MemoryHealth.danger);
    });

    test('danger falls back to warn once clearly below the threshold', () {
      expect(computeMemoryHealth(0.70, MemoryHealth.danger), MemoryHealth.warn);
    });

    test('danger falls all the way back to ok when usage drops sharply', () {
      expect(computeMemoryHealth(0.10, MemoryHealth.danger), MemoryHealth.ok);
    });
  });
}
