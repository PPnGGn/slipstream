import 'package:flutter/widgets.dart';

/// Flips [child] horizontally in a right-to-left language. For icons that
/// mean a direction (back arrow, "go on" chevron, "from → to"): an SVG does
/// not mirror by itself, and an arrow pointing the wrong way reads as the
/// opposite action. Icons that are symbols (a plus, a heart) must not use it.
class MirrorInRtl extends StatelessWidget {
  const MirrorInRtl({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Directionality.of(context) == TextDirection.ltr) return child;
    return Transform.flip(flipX: true, child: child);
  }
}
