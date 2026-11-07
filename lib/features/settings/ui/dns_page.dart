import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/ui/widgets/page_header.dart';
import 'package:slipstream/core/ui/widgets/radio_dot.dart';
import 'package:slipstream/features/dns/cubit/dns_cubit.dart';
import 'package:slipstream/features/dns/data/direct_dns.dart';
import 'package:slipstream/features/dns/data/dns_settings.dart';
import 'package:slipstream/features/dns/data/remote_dns.dart';
import 'package:slipstream/features/dns/ui/dns_labels.dart';
import 'package:slipstream/features/routing/cubit/ru_bypass_cubit.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';
import 'package:slipstream/features/settings/ui/widgets/help_sheet.dart';
import 'package:slipstream/features/settings/ui/widgets/reconnect_hint.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_row.dart';

/// Settings → DNS. The choices live in [DnsCubit] and reach the tunnel with the
/// next connection (VpnRepository.start); the page only draws them.
class DnsPage extends StatelessWidget {
  const DnsPage({super.key});

  static const _monoSubtitle = TextStyle(
    fontFamily: 'monospace',
    fontSize: 9.5,
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) {
    final dns = getIt<DnsCubit>();
    final ruBypass = getIt<RuBypassCubit>();
    final vpn = getIt<VpnServiceCubit>();
    final colors = AppColors.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'DNS',
              actions: [
                BoxIconButton(
                  iconPath: AppAssets.info,
                  onTap: () =>
                      _showHelp(context, fakeDnsAllowed: dns.fakeDnsAllowed),
                ),
              ],
            ),
            Expanded(
              child: BlocBuilder<DnsCubit, DnsSettings>(
                bloc: dns,
                builder: (context, settings) => ListView(
                  padding: const .fromLTRB(20, 6, 20, 28),
                  children: [
                    const SectionHeader(
                      'Remote DNS — queries via tunnel',
                      top: 12,
                    ),
                    SettingsGroup(
                      children: [
                        for (final remote in RemoteDns.values)
                          SettingsRow(
                            iconPath: _remoteIcon(remote),
                            hue: _remoteHue(remote),
                            title: remoteDnsTitle(remote),
                            subtitle: remoteDnsSubtitle(remote),
                            subtitleStyle: _monoSubtitle,
                            trailing: RadioDot(
                              selected: remote == settings.remote,
                            ),
                            onTap: () async {
                              if (remote == settings.remote) return;
                              await dns.setRemote(remote);
                              notifyIfTunnelActive(vpn);
                            },
                          ),
                      ],
                    ),
                    const SectionHeader('Direct DNS — for bypassed traffic'),
                    BlocBuilder<RuBypassCubit, RuBypassMode>(
                      bloc: ruBypass,
                      builder: (context, mode) {
                        final active = directDnsActive(mode);
                        final hint = directDnsHint(active: active);
                        return Column(
                          crossAxisAlignment: .stretch,
                          children: [
                            SettingsGroup(
                              children: [
                                for (final direct in DirectDns.values)
                                  SettingsRow(
                                    iconPath: _directIcon(direct),
                                    hue: _directHue(direct),
                                    title: directDnsTitle(direct),
                                    subtitle: directDnsSubtitle(direct),
                                    subtitleStyle: direct == DirectDns.yandex
                                        ? _monoSubtitle
                                        : null,
                                    trailing: RadioDot(
                                      selected: direct == settings.direct,
                                    ),
                                    enabled: active,
                                    onTap: () async {
                                      if (direct == settings.direct) return;
                                      await dns.setDirect(direct);
                                      notifyIfTunnelActive(vpn);
                                    },
                                  ),
                              ],
                            ),
                            if (hint != null)
                              Padding(
                                padding: const .fromLTRB(2, 8, 2, 0),
                                child: Text(
                                  hint,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.5,
                                    color: colors.textMuted,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    if (dns.fakeDnsAllowed) ...[
                      const SectionHeader('Options'),
                      SettingsGroup(
                        children: [
                          SettingsRow(
                            iconPath: AppAssets.bolt,
                            hue: TileHue.pink,
                            title: 'Fake DNS',
                            subtitle: fakeDnsSubtitle(
                              enabled: settings.fakeDns,
                            ),
                            switchValue: settings.fakeDns,
                            onSwitch: (value) async {
                              await dns.setFakeDns(enabled: value);
                              notifyIfTunnelActive(vpn);
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _remoteIcon(RemoteDns remote) => switch (remote) {
    RemoteDns.cloudflare => AppAssets.cloud,
    RemoteDns.google => AppAssets.search,
    RemoteDns.xray => AppAssets.chip,
  };

  static TileHue _remoteHue(RemoteDns remote) => switch (remote) {
    RemoteDns.cloudflare => TileHue.amber,
    RemoteDns.google => TileHue.blue,
    RemoteDns.xray => TileHue.violet,
  };

  static String _directIcon(DirectDns direct) => switch (direct) {
    DirectDns.yandex => AppAssets.pin,
    DirectDns.system => AppAssets.server,
  };

  static TileHue _directHue(DirectDns direct) => switch (direct) {
    DirectDns.yandex => TileHue.blue,
    DirectDns.system => TileHue.slate,
  };

  static void _showHelp(BuildContext context, {required bool fakeDnsAllowed}) {
    showHelpSheet(
      context,
      title: 'DNS',
      entries: [
        const HelpEntry(
          title: 'Remote DNS',
          body:
              'Looks up names for traffic that goes through the VPN. '
              'Cloudflare and Google use DNS over HTTPS (encrypted). Xray '
              'built-in is plain DNS to 1.1.1.1 inside the tunnel: your '
              'provider does not see it, the VPN server does.',
        ),
        const HelpEntry(
          title: 'Direct DNS',
          body:
              'Looks up Russian names (.ru, .рф, Russian services) for '
              'traffic that bypasses the VPN. Yandex DNS is encrypted. The '
              'system resolver is the phone\'s own DNS, usually your '
              'operator\'s: sites open the same, but the operator sees these '
              'names. Used only while the RU bypass is on.',
        ),
        if (fakeDnsAllowed)
          const HelpEntry(
            title: 'Fake DNS',
            body:
                'Apps get a made-up address at once and the VPN finds the '
                'real one later, so the first connection is faster. If an '
                'app stops opening, turn it off.',
          ),
        const HelpEntry(
          title: 'When applied',
          body:
              'Changes take effect on reconnect.\n'
              'Not applied to servers whose config has its own routing '
              'rules (set by the VPN provider).\n'
              'With strict Private DNS in Android settings, apps look names '
              'up through it and not through these resolvers.',
        ),
      ],
    );
  }
}
