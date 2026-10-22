import 'package:flutter/material.dart';
import 'package:slipstream/core/theme/app_colors.dart';

/// The design's switch: accent track when on, chip track with a border when
/// off, white knob. Null [onChanged] dims it and ignores taps.
class WaveSwitch extends StatelessWidget {
  const WaveSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onChanged = this.onChanged;

    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged(!value),
      child: Opacity(
        opacity: onChanged == null ? 0.45 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 48,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            gradient: value
                ? LinearGradient(colors: colors.brandGradient)
                : null,
            color: value ? null : colors.chip,
            border: value ? null : Border.all(color: colors.border, width: 1.5),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.switchKnob,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                    color: colors.switchKnobShadow,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
