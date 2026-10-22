import 'package:flutter/material.dart';
import 'package:slipstream/core/theme/app_colors.dart';

/// The design's segmented control: options on a chip-colored track, the
/// selected one raised. Null [onChanged] dims it and ignores taps.
class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T? selected;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onChanged = this.onChanged;

    return Opacity(
      opacity: onChanged == null ? 0.45 : 1,
      child: Container(
        padding: const .all(4),
        decoration: BoxDecoration(
          color: colors.chip,
          borderRadius: .circular(12),
        ),
        child: Row(
          spacing: 6,
          children: [
            for (final (value, label) in options)
              Expanded(
                child: GestureDetector(
                  onTap: onChanged == null ? null : () => onChanged(value),
                  behavior: .opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 32,
                    alignment: .center,
                    decoration: BoxDecoration(
                      color: value == selected
                          ? colors.segment
                          : Colors.transparent,
                      borderRadius: .circular(9),
                      boxShadow: value == selected
                          ? const [
                              BoxShadow(
                                color: Color(0x33141420),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: .w600,
                        color: value == selected
                            ? colors.textPrimary
                            : colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
