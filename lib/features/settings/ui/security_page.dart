import 'package:flutter/material.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/ui/widgets/segmented_pill.dart';
import 'package:slipstream/features/settings/ui/widgets/coming_soon_page.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_row.dart';

/// Settings → Security & tunnel. Not built yet: every control is inactive
/// and shows a neutral value (off / nothing selected).
class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPage(
      title: 'Security & tunnel',
      children: [
        SizedBox(height: 14),
        SettingsGroup(
          children: [
            SettingsRow(
              iconPath: AppAssets.kill,
              hue: TileHue.red,
              title: 'Kill switch',
              subtitle: 'Block internet if the tunnel drops',
              switchValue: false,
              enabled: false,
            ),
            SettingsRow(
              iconPath: AppAssets.refresh,
              hue: TileHue.green,
              title: 'Always-On VPN',
              subtitle: 'Reconnect automatically, survive reboot',
              switchValue: false,
              enabled: false,
            ),
            SettingsRow(
              iconPath: AppAssets.wifi,
              hue: TileHue.teal,
              title: 'Allow LAN connections',
              subtitle: 'Share the proxy with devices on your network',
              switchValue: false,
              enabled: false,
            ),
            SettingsRow(
              iconPath: AppAssets.ipv6,
              hue: TileHue.blue,
              title: 'IPv6',
              subtitle: 'Route IPv6 traffic inside the tunnel',
              switchValue: false,
              enabled: false,
            ),
          ],
        ),
        SectionHeader('Xray memory limit', top: 18),
        SettingsGroup(
          children: [
            SettingsRow(
              iconPath: AppAssets.memory,
              hue: TileHue.amber,
              title: 'Memory limit',
              subtitle: 'Lower saves battery; ∞ is fastest on heavy traffic',
              enabled: false,
              footer: SegmentedPill<String>(
                options: [
                  ('64', '64 MB'),
                  ('128', '128 MB'),
                  ('256', '256 MB'),
                  ('unlimited', '∞'),
                ],
                selected: null,
                onChanged: null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
