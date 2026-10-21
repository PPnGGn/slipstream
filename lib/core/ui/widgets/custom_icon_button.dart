import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class CustomIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final String iconPath;
  final double size;
  final double radius;
  final double iconSize;
  final Color? iconColor;
  final Color? borderColor;
  final Color? color;
  final List<Color>? gradientColors;
  const CustomIconButton({
    super.key,
    required this.onTap,
    required this.iconPath,
    this.size = 40,
    this.radius = 12,
    this.iconSize = 20,
    this.iconColor,
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
        height: size,
        width: size,
        alignment: .center,
        decoration: BoxDecoration(
          borderRadius: .circular(radius),
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1)
              : null,
          gradient: hasGradient
              ? LinearGradient(colors: gradientColors!)
              : null,
          color: hasGradient ? null : color,
          // Gradient buttons sit raised above the page (design shadow).
          boxShadow: hasGradient
              ? const [
                  BoxShadow(
                    color: Color(0x40393A5A),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: SvgPicture.asset(
          iconPath,
          width: iconSize,
          height: iconSize,
          colorFilter: iconColor != null ? .mode(iconColor!, .srcIn) : null,
        ),
      ),
    );
  }
}
