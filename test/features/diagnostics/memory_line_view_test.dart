import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/features/diagnostics/cubit/memory_usage_cubit.dart';
import 'package:slipstream/features/diagnostics/ui/memory_line_view.dart';

const _mb = 1024 * 1024;

void main() {
  group('memoryLineView', () {
    test('rounds the megabytes and names the health', () {
      final view = memoryLineView(
        const MemoryUsage(bytes: 23 * _mb + 300 * 1024),
        ios: false,
      );

      expect(view.value, '23 MB');
      expect(view.label, 'Normal');
      expect(view.health, MemoryHealth.ok);
    });

    test('warn is "High", danger is "Critical"', () {
      expect(
        memoryLineView(
          const MemoryUsage(bytes: 100 * _mb, health: MemoryHealth.warn),
          ios: false,
        ).label,
        'High',
      );
      expect(
        memoryLineView(
          const MemoryUsage(bytes: 140 * _mb, health: MemoryHealth.danger),
          ios: false,
        ).label,
        'Critical',
      );
    });

    test('iOS shows the budget next to the value', () {
      final view = memoryLineView(
        const MemoryUsage(bytes: 38 * _mb),
        ios: true,
      );

      expect(view.value, '38/50 MB');
    });

    test('without a reading there is a dash and no verdict', () {
      final view = memoryLineView(const MemoryUsage(), ios: false);

      expect(view.value, '— MB');
      expect(view.label, isNull);
      expect(view.health, isNull);
    });
  });
}
