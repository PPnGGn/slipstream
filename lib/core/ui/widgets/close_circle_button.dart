import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/core/theme/app_colors.dart';

/// × on a circle. One button for every close action: in bottom sheet
/// headers it follows the theme; [overCamera] (the QR scanner) keeps a white
/// × on a dark translucent circle, because the background is a live image.
class CloseCircleButton extends StatelessWidget {
  const CloseCircleButton({
    super.key,
    required this.onPressed,
    this.overCamera = false,
  });

  final VoidCallback onPressed;
  final bool overCamera;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return IconButton(
      onPressed: onPressed,
      tooltip: 'Close',
      style: IconButton.styleFrom(
        backgroundColor: overCamera ? Colors.black54 : colors.chip,
      ),
      icon: SvgPicture.asset(
        AppAssets.close,
        width: 16,
        height: 16,
        colorFilter: .mode(
          overCamera ? Colors.white : colors.textSecondary,
          .srcIn,
        ),
      ),
    );
  }
}
