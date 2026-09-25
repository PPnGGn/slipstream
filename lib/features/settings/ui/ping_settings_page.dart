import 'package:flutter/material.dart';
import 'package:slipstream/core/theme/app_theme.dart';
import 'package:slipstream/features/ping/presentation/ui/ping_settings_section.dart';
import 'package:slipstream/features/settings/ui/widgets/help_sheet.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';

class PingSettingsPage extends StatelessWidget {
  const PingSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ping'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'About these settings',
            onPressed: () => showHelpSheet(
              context,
              title: 'Ping',
              entries: const [
                HelpEntry(
                  title: 'Measurement',
                  body:
                      'TCP connection to the server; UDP (QUIC) for '
                      'Hysteria2. Up to 3 attempts, the result is the '
                      'median.\n'
                      'Checks only that the server is reachable, not that '
                      'the VPN works.',
                ),
                HelpEntry(
                  title: 'Legend',
                  body:
                      'green — under 80 ms\n'
                      'yellow — 80–160 ms\n'
                      'red — over 160 ms\n'
                      'timeout — no response\n'
                      'refused — connection rejected, port closed\n'
                      'no dns — server address not found\n'
                      'error — network error, usually on the device side\n'
                      'n/a — not measurable for this protocol (mKCP)',
                ),
                HelpEntry(
                  title: 'Ping on launch',
                  body:
                      'Measures all servers at startup. Manually: the button '
                      'on a subscription, or pull down on the list.',
                ),
                HelpEntry(
                  title: 'Sort servers by latency',
                  body:
                      'Sorts by ping once measuring finishes. The order stays '
                      'fixed while measuring.',
                ),
                HelpEntry(
                  title: 'Latency display',
                  body: 'Numbers — value in ms. Dots — color only.',
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDims.horizontalPadding,
          AppDims.gapS,
          AppDims.horizontalPadding,
          AppDims.gapXxl,
        ),
        children: [
          const SectionHeader('Ping'),
          const PingSettingsSection(),
        ],
      ),
    );
  }
}
