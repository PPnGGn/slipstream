import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/ui/widgets/segmented_pill.dart';
import 'package:slipstream/features/settings/ui/widgets/coming_soon_page.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_row.dart';

/// Settings → Split tunneling. Not built yet: no mode is selected and the
/// app list is an empty placeholder — no made-up apps.
class SplitTunnelingPage extends StatelessWidget {
  const SplitTunnelingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ComingSoonPage(
      title: 'Split tunneling',
      children: [
        const SizedBox(height: 14),
        const SegmentedPill<String>(
          options: [('proxy', 'Proxy selected'), ('bypass', 'Bypass selected')],
          selected: null,
          onChanged: null,
        ),
        Padding(
          padding: const .fromLTRB(2, 8, 2, 12),
          child: Text(
            'Choose whether the selected apps go through the tunnel or '
            'connect directly.',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: colors.textMuted,
            ),
          ),
        ),
        const SettingsGroup(
          children: [
            SettingsRow(
              iconPath: AppAssets.sysApps,
              hue: TileHue.slate,
              title: 'Include system apps',
              subtitle: 'WebView, Play Services and other services',
              switchValue: false,
              enabled: false,
            ),
          ],
        ),
        const SectionHeader('0 apps', top: 18),
        SettingsGroup(
          children: [
            Padding(
              padding: const .symmetric(horizontal: 20, vertical: 28),
              child: Column(
                spacing: 10,
                children: [
                  SvgPicture.asset(
                    AppAssets.apps,
                    width: 26,
                    height: 26,
                    colorFilter: .mode(colors.textMuted, .srcIn),
                  ),
                  Text(
                    'The app list arrives with this feature',
                    textAlign: .center,
                    style: TextStyle(fontSize: 12.5, color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
