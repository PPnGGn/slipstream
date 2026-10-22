import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/core/theme/app_colors.dart';

/// Top bar of a sub-page: the boxed back button, the title and optional
/// boxed actions on the right. Replaces the Material AppBar on v3 screens.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, this.title, this.actions = const []});

  /// Null on Settings, which shows its big title inside the list instead.
  final String? title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const .fromLTRB(16, 10, 16, 8),
      child: Row(
        spacing: 8,
        children: [
          BoxIconButton(
            iconPath: AppAssets.arrowLeft,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: title == null
                ? const SizedBox.shrink()
                : Text(
                    title!,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: .w700,
                      letterSpacing: -0.34,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// 34 px square button with a border, used for back and header actions.
class BoxIconButton extends StatelessWidget {
  const BoxIconButton({super.key, required this.iconPath, required this.onTap});

  final String iconPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: .opaque,
      child: Container(
        width: 34,
        height: 34,
        alignment: .center,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: .circular(11),
          border: .all(color: colors.border),
        ),
        child: SvgPicture.asset(
          iconPath,
          width: 16,
          height: 16,
          colorFilter: .mode(colors.textSecondary, .srcIn),
        ),
      ),
    );
  }
}
