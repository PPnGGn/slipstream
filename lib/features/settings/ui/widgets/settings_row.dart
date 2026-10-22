import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/ui/widgets/icon_tile.dart';
import 'package:slipstream/core/ui/widgets/wave_switch.dart';

/// One settings row of design v3: icon tile, title and subtitle, then
/// an optional value, badge, chevron or switch. A disabled row is dimmed
/// and ignores taps — that is how not-yet-built features look.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.iconPath,
    this.hue,
    this.subtitle,
    this.subtitleStyle,
    this.value,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.switchValue,
    this.onSwitch,
    this.enabled = true,
    this.footer,
  });

  final String title;
  final String? iconPath;
  final TileHue? hue;
  final String? subtitle;

  /// Merged over the default subtitle style (e.g. mono or an error color).
  final TextStyle? subtitleStyle;

  /// Muted text on the right, before the chevron.
  final String? value;

  /// Custom widget on the right (a badge, a button).
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  /// Non-null: the row ends with a switch.
  final bool? switchValue;
  final ValueChanged<bool>? onSwitch;
  final bool enabled;

  /// Extra content under the row (a segmented control, a progress bar).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final iconPath = this.iconPath;
    final switchValue = this.switchValue;
    final onSwitch = enabled ? this.onSwitch : null;
    final onTap = !enabled
        ? null
        : this.onTap ??
              (switchValue != null && onSwitch != null
                  ? () => onSwitch(!switchValue)
                  : null);

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const .symmetric(horizontal: 14, vertical: 11),
        child: Row(
          spacing: 13,
          children: [
            if (iconPath != null)
              IconTile(
                iconPath: iconPath,
                color: colors.tileHue(hue ?? TileHue.slate),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                mainAxisSize: .min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: .w500,
                      height: 1.25,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: colors.textMuted,
                      ).merge(subtitleStyle),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
            if (value != null)
              Text(
                value!,
                style: TextStyle(fontSize: 13, color: colors.textMuted),
              ),
            if (showChevron)
              SvgPicture.asset(
                AppAssets.chevronRight,
                width: 13,
                height: 13,
                colorFilter: .mode(colors.textMuted, .srcIn),
              ),
            if (switchValue != null)
              IgnorePointer(
                ignoring: !enabled,
                // A disabled row dims as a whole; the no-op callback keeps
                // the switch from dimming itself a second time.
                child: WaveSwitch(
                  value: switchValue,
                  onChanged: enabled ? onSwitch : (_) {},
                ),
              ),
          ],
        ),
      ),
    );

    return InkWell(
      onTap: onTap,
      highlightColor: colors.rowHover,
      splashColor: Colors.transparent,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Opacity(opacity: enabled ? 1 : 0.45, child: row),
          if (footer != null)
            // A footer control dims itself when disabled (a SegmentedPill
            // without onChanged), so the row only blocks its taps.
            IgnorePointer(
              ignoring: !enabled,
              child: Padding(
                padding: const .fromLTRB(14, 0, 14, 12),
                child: footer,
              ),
            ),
        ],
      ),
    );
  }
}
