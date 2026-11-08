import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// Top of a page whose feature is not built yet: the page shows the future
/// layout, but nothing on it works.
class ComingSoonBanner extends StatelessWidget {
  const ComingSoonBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const .symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: .circular(14),
      ),
      child: Row(
        spacing: 11,
        children: [
          SvgPicture.asset(
            AppAssets.sparkle,
            width: 18,
            height: 18,
            colorFilter: .mode(colors.accentIcon, .srcIn),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              spacing: 2,
              children: [
                Text(
                  context.l10n.comingSoonTitle,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: .w700,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  context.l10n.comingSoonBody,
                  style: TextStyle(fontSize: 11.5, color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
