import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';

/// White × on a dark translucent circle. One button for every close action:
/// over the QR scanner's camera and in bottom sheet headers.
class CloseCircleButton extends StatelessWidget {
  const CloseCircleButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: 'Close',
      style: IconButton.styleFrom(backgroundColor: Colors.black54),
      icon: SvgPicture.asset(
        AppAssets.close,
        width: 16,
        height: 16,
        colorFilter: const .mode(Colors.white, .srcIn),
      ),
    );
  }
}
