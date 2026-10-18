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

  group('memoryBudgetBytesFor', () {
    const mb = 1024 * 1024;

    test('iOS keeps the Network Extension jetsam limit', () {
      expect(memoryBudgetBytesFor(ios: true), 50 * mb);
    });

    test('Android: measured peaks stay green, 90 MB warns, 128 MB is danger', () {
      final budget = memoryBudgetBytesFor(ios: false);
      MemoryHealth at(int megabytes) =>
          computeMemoryHealth(megabytes * mb / budget, MemoryHealth.ok);

      expect(at(46), MemoryHealth.ok); // plain config, video peak
      expect(at(82), MemoryHealth.ok); // RU geo rules, video peak
      expect(at(90), MemoryHealth.warn);
      expect(at(128), MemoryHealth.danger); // the level before the memory fixes
    });
  });
}
