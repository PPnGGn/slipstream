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
import 'package:slipstream/features/help/ui/help_button.dart';
import 'package:slipstream/features/help/ui/help_topics.dart';
import 'package:slipstream/features/settings/ui/widgets/reconnect_hint.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_row.dart';
import 'package:slipstream/l10n/l10n_context.dart';

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
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: l10n.dnsTitle,
              actions: [
                HelpButton(
                  topic: (l10n) =>
                      dnsHelp(l10n, fakeDnsAllowed: dns.fakeDnsAllowed),
                ),
              ],
            ),
            Expanded(
              child: BlocBuilder<DnsCubit, DnsSettings>(
                bloc: dns,
                builder: (context, settings) => ListView(
                  padding: const .fromLTRB(20, 6, 20, 28),
                  children: [
                    SectionHeader(l10n.dnsRemoteHeader, top: 12),
                    SettingsGroup(
                      children: [
                        for (final remote in RemoteDns.values)
                          SettingsRow(
                            iconPath: _remoteIcon(remote),
                            hue: _remoteHue(remote),
                            title: remoteDnsTitle(l10n, remote),
                            subtitle: remoteDnsSubtitle(l10n, remote),
                            subtitleStyle: _monoSubtitle,
                            trailing: RadioDot(
                              selected: remote == settings.remote,
                            ),
                            onTap: () async {
                              if (remote == settings.remote) return;
                              await dns.setRemote(remote);
                              if (context.mounted) {
                                notifyIfTunnelActive(l10n, vpn);
                              }
                            },
                          ),
                      ],
                    ),
                    SectionHeader(l10n.dnsDirectHeader),
                    BlocBuilder<RuBypassCubit, RuBypassMode>(
                      bloc: ruBypass,
                      builder: (context, mode) {
                        final active = directDnsActive(mode);
                        final hint = directDnsHint(l10n, active: active);
                        return Column(
                          crossAxisAlignment: .stretch,
                          children: [
                            SettingsGroup(
                              children: [
                                for (final direct in DirectDns.values)
                                  SettingsRow(
                                    iconPath: _directIcon(direct),
                                    hue: _directHue(direct),
                                    title: directDnsTitle(l10n, direct),
                                    subtitle: directDnsSubtitle(l10n, direct),
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
                                      if (context.mounted) {
                                        notifyIfTunnelActive(l10n, vpn);
                                      }
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
                      SectionHeader(l10n.dnsOptions),
                      SettingsGroup(
                        children: [
                          SettingsRow(
                            iconPath: AppAssets.bolt,
                            hue: TileHue.pink,
                            title: 'Fake DNS',
                            subtitle: fakeDnsSubtitle(
                              l10n,
                              enabled: settings.fakeDns,
                            ),
                            switchValue: settings.fakeDns,
                            onSwitch: (value) async {
                              await dns.setFakeDns(enabled: value);
                              if (context.mounted) {
                                notifyIfTunnelActive(l10n, vpn);
                              }
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
}
