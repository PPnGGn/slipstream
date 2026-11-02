import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/ui/widgets/page_header.dart';
import 'package:slipstream/features/security/cubit/ipv6_cubit.dart';
import 'package:slipstream/features/security/cubit/kill_switch_cubit.dart';
import 'package:slipstream/features/security/ui/security_labels.dart';
import 'package:slipstream/features/settings/ui/widgets/reconnect_hint.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_row.dart';

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
    final colors = AppColors.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PageHeader(title: 'Security & tunnel'),
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
                          subtitle: killSwitchSubtitle(enabled: enabled),
                          switchValue: enabled,
                          onSwitch: (value) {
                            _killSwitch.setEnabled(enabled: value);
                            notifyIfTunnelActive(_vpn);
                          },
                        ),
                      ),
                      BlocBuilder<Ipv6Cubit, bool>(
                        bloc: _ipv6,
                        builder: (context, enabled) => SettingsRow(
                          iconPath: AppAssets.ipv6,
                          hue: TileHue.blue,
                          title: 'IPv6',
                          subtitle: ipv6Subtitle(enabled: enabled),
                          switchValue: enabled,
                          onSwitch: (value) {
                            _ipv6.setEnabled(enabled: value);
                            notifyIfTunnelActive(_vpn);
                          },
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const .fromLTRB(2, 8, 2, 0),
                    child: Text(
                      'Kill switch: if the tunnel is lost and cannot come back '
                      '(Android stopped the app, or the system restarted the '
                      'VPN), traffic stays blocked until you reconnect or turn '
                      'the VPN off. A server that fails on the first connect '
                      'only shows an error. It does not cover everything: '
                      'when Android stops the app, traffic can leave the VPN '
                      'for a few seconds while the tunnel comes back, and if '
                      'the app itself crashes the VPN is simply gone. With '
                      "Android's own Always-on VPN turned on, the system "
                      'brings the VPN back when you turn it off from the app.\n\n'
                      'With IPv6 off the tunnel carries IPv4 only. Apps and '
                      'sites that need IPv6 fall back to IPv4 on their own.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: colors.textMuted,
                      ),
                    ),
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
