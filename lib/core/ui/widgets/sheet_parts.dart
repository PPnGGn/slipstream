import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/ui/widgets/close_circle_button.dart';

/// The drag handle at the top of every bottom sheet.
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const .only(top: 4, bottom: 14),
        decoration: BoxDecoration(
          color: colors.border,
          borderRadius: .circular(100),
        ),
      ),
    );
  }
}

/// Sheet header: accent icon tile, title with an optional mono subtitle,
/// and the [CloseCircleButton].
class SheetTitleRow extends StatelessWidget {
  const SheetTitleRow({
    super.key,
    required this.iconPath,
    required this.title,
    this.subtitle,
  });

  final String iconPath;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      spacing: 11,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: .center,
          decoration: BoxDecoration(
            color: colors.primarySoft,
            borderRadius: .circular(12),
          ),
          child: SvgPicture.asset(
            iconPath,
            width: 17,
            height: 17,
            colorFilter: .mode(colors.accentIcon, .srcIn),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            mainAxisSize: .min,
            spacing: 2,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: .w700,
                  color: colors.textPrimary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!.toUpperCase(),
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9.5,
                    fontWeight: .w600,
                    letterSpacing: 0.8,
                    color: colors.textMuted,
                  ),
                ),
            ],
          ),
        ),
        CloseCircleButton(onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
