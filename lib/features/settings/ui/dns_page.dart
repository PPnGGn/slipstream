import 'package:flutter/material.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/ui/widgets/radio_dot.dart';
import 'package:slipstream/features/settings/ui/widgets/coming_soon_page.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_row.dart';

/// Settings → DNS. Not built yet: no resolver is selected and every
/// control is inactive.
class DnsPage extends StatelessWidget {
  const DnsPage({super.key});

  static const _monoSubtitle = TextStyle(
    fontFamily: 'monospace',
    fontSize: 9.5,
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPage(
      title: 'DNS',
      children: [
        SectionHeader('Remote DNS — queries via tunnel', top: 18),
        SettingsGroup(
          children: [
            SettingsRow(
              iconPath: AppAssets.cloud,
              hue: TileHue.amber,
              title: 'Cloudflare DoH',
              subtitle: 'https://cloudflare-dns.com/dns-query',
              subtitleStyle: _monoSubtitle,
              trailing: RadioDot(selected: false),
              enabled: false,
            ),
            SettingsRow(
              iconPath: AppAssets.search,
              hue: TileHue.blue,
              title: 'Google DoH',
              subtitle: 'https://dns.google/dns-query',
              subtitleStyle: _monoSubtitle,
              trailing: RadioDot(selected: false),
              enabled: false,
            ),
            SettingsRow(
              iconPath: AppAssets.chip,
              hue: TileHue.violet,
              title: 'Xray built-in',
              subtitle: 'UDP 1.1.1.1:53 VIA TUNNEL',
              subtitleStyle: _monoSubtitle,
              trailing: RadioDot(selected: false),
              enabled: false,
            ),
          ],
        ),
        SectionHeader('Direct DNS — for bypassed traffic', top: 18),
        SettingsGroup(
          children: [
            SettingsRow(
              iconPath: AppAssets.server,
              hue: TileHue.slate,
              title: 'System resolver',
              subtitle: 'Resolves traffic that bypasses the tunnel',
              enabled: false,
            ),
          ],
        ),
        SectionHeader('Options', top: 18),
        SettingsGroup(
          children: [
            SettingsRow(
              iconPath: AppAssets.bolt,
              hue: TileHue.pink,
              title: 'Fake DNS',
              subtitle:
                  'Instant fake IPs inside the tunnel, faster first '
                  'connect',
              switchValue: false,
              enabled: false,
            ),
            SettingsRow(
              iconPath: AppAssets.shieldX,
              hue: TileHue.red,
              title: 'Block ads via DNS',
              subtitle: 'NXDOMAIN for known ad domains',
              switchValue: false,
              enabled: false,
            ),
          ],
        ),
      ],
    );
  }
}
