import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// The design's 36 px colored icon square on settings rows: a faint fill
/// and border in the row's hue, the icon in the hue itself.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.iconPath, required this.color});

  final String iconPath;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: .center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: .circular(11),
        border: .all(color: color.withValues(alpha: 0.3)),
      ),
      child: SvgPicture.asset(
        iconPath,
        width: 18,
        height: 18,
        colorFilter: .mode(color, .srcIn),
      ),
    );
  }
}
