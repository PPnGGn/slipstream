import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class CustomIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final String iconPath;
  final Color? borderColor;
  final Color? color;
  final List<Color>? gradientColors;
  const CustomIconButton({
    super.key,
    required this.onTap,
    required this.iconPath,
    this.borderColor,
    this.color,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final hasGradient = gradientColors?.isNotEmpty ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: .all(10),
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          borderRadius: .circular(12),
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1)
              : null,
          gradient: hasGradient
              ? LinearGradient(colors: gradientColors!)
              : null,
          color: hasGradient ? null : color,
        ),
        child: SvgPicture.asset(iconPath),
      ),
    );
  }
}
