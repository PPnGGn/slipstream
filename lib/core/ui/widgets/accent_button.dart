import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/core/theme/app_colors.dart';

/// The design's main button: brand gradient (solid green in Phosphor) with
/// ink text. Null [onPressed] dims it and ignores taps.
class AccentButton extends StatelessWidget {
  const AccentButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.iconPath,
    this.height = 50,
    this.radius = 15,
    this.fontSize = 14,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? iconPath;
  final double height;
  final double radius;
  final double fontSize;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final enabled = onPressed != null && !loading;

    return GestureDetector(
      onTap: enabled ? onPressed : null,
      behavior: .opaque,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onPressed == null ? 0.45 : 1,
        child: Container(
          height: height,
          padding: const .symmetric(horizontal: 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors.brandGradient),
            borderRadius: .circular(radius),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40393A5A),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: .min,
            mainAxisAlignment: .center,
            spacing: 8,
            children: [
              if (loading)
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(colors.ink),
                  ),
                )
              else if (iconPath != null)
                SvgPicture.asset(
                  iconPath!,
                  width: 14,
                  height: 14,
                  colorFilter: .mode(colors.ink, .srcIn),
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: .w700,
                  color: colors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
