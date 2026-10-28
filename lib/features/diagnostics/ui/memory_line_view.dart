import 'package:slipstream/features/diagnostics/cubit/memory_usage_cubit.dart';

/// What the memory line on the home screen says: `23 MB · Normal`.
class MemoryLineView {
  const MemoryLineView({required this.value, this.label, this.health});

  /// `23 MB`; on iOS `23/50 MB`; `— MB` while there is no reading.
  final String value;

  /// `Normal`, `High` or `Critical`; null without a reading.
  final String? label;

  /// Picks the colour of the label; null without a reading.
  final MemoryHealth? health;
}

/// Pure, so the wording is tested without a widget. The budget is shown on
/// iOS only: there it is the real kill threshold of the extension, while on
/// Android there is no ceiling worth showing (see [memoryBudgetBytesFor]).
MemoryLineView memoryLineView(MemoryUsage usage, {required bool ios}) {
  final bytes = usage.bytes;
  if (bytes == null) return const MemoryLineView(value: '— MB');

  final value = ios
      ? '${_mb(bytes)}/${_mb(memoryBudgetBytesFor(ios: true))} MB'
      : '${_mb(bytes)} MB';
  return MemoryLineView(
    value: value,
    label: switch (usage.health) {
      MemoryHealth.ok => 'Normal',
      MemoryHealth.warn => 'High',
      MemoryHealth.danger => 'Critical',
    },
    health: usage.health,
  );
}

int _mb(int bytes) => (bytes / (1024 * 1024)).round();
