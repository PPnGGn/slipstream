import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart' show TileHue;
import 'package:slipstream/core/ui/widgets/page_header.dart';
import 'package:slipstream/features/help/ui/help_button.dart';
import 'package:slipstream/features/help/ui/help_topics.dart';
import 'package:slipstream/features/security/cubit/ipv6_cubit.dart';
import 'package:slipstream/features/security/cubit/kill_switch_cubit.dart';
import 'package:slipstream/features/security/ui/security_labels.dart';
import 'package:slipstream/features/settings/ui/widgets/reconnect_hint.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_row.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// Settings → Security & tunnel (Android). The choices live in their cubits
/// and reach the VPN service with the next connection.
class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final _killSwitch = getIt<KillSwitchCubit>();
  final _ipv6 = getIt<Ipv6Cubit>();
  final _vpn = getIt<VpnServiceCubit>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: context.l10n.securityTitle,
              actions: [HelpButton(topic: securityHelp)],
            ),
            Expanded(
              child: ListView(
                padding: const .fromLTRB(20, 6, 20, 28),
                children: [
                  SettingsGroup(
                    children: [
                      BlocBuilder<KillSwitchCubit, bool>(
                        bloc: _killSwitch,
                        builder: (context, enabled) => SettingsRow(
                          iconPath: AppAssets.kill,
                          hue: TileHue.red,
                          title: 'Kill switch',
                          subtitle: killSwitchSubtitle(
                            context.l10n,
                            enabled: enabled,
                          ),
                          switchValue: enabled,
                          onSwitch: (value) {
                            _killSwitch.setEnabled(enabled: value);
                            notifyIfTunnelActive(context.l10n, _vpn);
                          },
                        ),
                      ),
                      BlocBuilder<Ipv6Cubit, bool>(
                        bloc: _ipv6,
                        builder: (context, enabled) => SettingsRow(
                          iconPath: AppAssets.ipv6,
                          hue: TileHue.blue,
                          title: 'IPv6',
                          subtitle: ipv6Subtitle(context.l10n, enabled: enabled),
                          switchValue: enabled,
                          onSwitch: (value) {
                            _ipv6.setEnabled(enabled: value);
                            notifyIfTunnelActive(context.l10n, _vpn);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
