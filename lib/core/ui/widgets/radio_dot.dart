import 'package:flutter/material.dart';
import 'package:slipstream/core/theme/app_colors.dart';

/// 16 px radio: a thick accent ring around a white dot when selected, a thin
/// border when not.
class RadioDot extends StatelessWidget {
  const RadioDot({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: .circle,
        color: selected ? const Color(0xFFFFFFFF) : Colors.transparent,
        border: selected
            ? .all(color: colors.accentIcon, width: 5)
            : .all(color: colors.border, width: 1.6),
      ),
    );
  }
}
