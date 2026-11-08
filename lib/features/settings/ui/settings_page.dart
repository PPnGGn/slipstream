import 'dart:io';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/update_service/update_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/ui/toast/show_toast.dart';
import 'package:slipstream/core/ui/widgets/page_header.dart';
import 'package:slipstream/features/appearance/cubit/home_layout_cubit.dart';
import 'package:slipstream/features/appearance/data/home_layout.dart';
import 'package:slipstream/features/appearance/ui/appearance_labels.dart';
import 'package:slipstream/features/dns/cubit/dns_cubit.dart';
import 'package:slipstream/features/dns/data/dns_settings.dart';
import 'package:slipstream/features/dns/ui/dns_labels.dart';
import 'package:slipstream/features/diagnostics/cubit/memory_monitor_cubit.dart';
import 'package:slipstream/features/diagnostics/data/memory_monitor_mode.dart';
import 'package:slipstream/features/geo/cubit/geo_cubit.dart';
import 'package:slipstream/features/ping/data/ping_settings_store.dart';
import 'package:slipstream/features/ping/presentation/ping_cubit.dart';
import 'package:slipstream/features/routing/cubit/ad_block_cubit.dart';
import 'package:slipstream/features/routing/cubit/custom_rules_cubit.dart';
import 'package:slipstream/features/routing/cubit/ru_bypass_cubit.dart';
import 'package:slipstream/features/routing/data/ad_block_mode.dart';
import 'package:slipstream/features/routing/data/custom_rule.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';
import 'package:slipstream/features/routing/ui/routing_labels.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_row.dart';
import 'package:slipstream/features/split_tunnel/cubit/split_tunnel_cubit.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_settings.dart';
import 'package:slipstream/features/auto_connect/cubit/auto_connect_cubit.dart';
import 'package:slipstream/features/auto_connect/data/auto_connect_support.dart';
import 'package:slipstream/features/auto_connect/ui/auto_connect_labels.dart';
import 'package:slipstream/features/security/data/security_support.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_support.dart';
import 'package:slipstream/features/split_tunnel/ui/split_tunnel_labels.dart';
import 'package:slipstream/features/subscriptions/cubit/subscription_auto_update_cubit.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/auto_update_interval.dart';
import 'package:slipstream/features/subscriptions/ui/auto_update_labels.dart';
import 'package:slipstream/features/update/data/updater_api.g.dart';
import 'package:slipstream/features/update/ui/update_toasts.dart';
import 'package:slipstream/features/update/ui/widgets/update_dialog.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';
import 'package:slipstream/features/language/cubit/language_cubit.dart';
import 'package:slipstream/features/language/data/app_language.dart';
import 'package:slipstream/l10n/l10n_context.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _updateCubit = getIt<UpdateServiceCubit>();

  // Tap on the Version row. What to show for each updater state is decided
  // by updateCheckFeedback; this only asks GitHub first when there is no
  // downloaded, downloading or conflicting update to show as it is.
  Future<void> _checkForUpdates() async {
    final app = await getIt<UpdateInstaller>().getAppVersion();
    if (!mounted) return;

    if (!isUpdateStateWorthShowing(_updateCubit.state)) {
      await _updateCubit.check(userInitiated: true);
      if (!mounted) return;
    }

    final feedback = updateCheckFeedback(
      context.l10n,
      _updateCubit.state,
      '${app.version} (${app.buildNumber})',
    );
    switch (feedback) {
      case OpenUpdateDialog():
        await showUpdateDialog(context);
      case ShowUpdateToast(:final spec):
        showToastSpec(spec);
      case NoUpdateFeedback():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppThemeCubit, AppThemeState>(
      bloc: getIt<AppThemeCubit>(),
      builder: (context, themeState) => BlocBuilder<HomeLayoutCubit, HomeLayout>(
        bloc: getIt<HomeLayoutCubit>(),
        builder: (context, layout) {
          final colors = AppColors.of(context);

          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  const PageHeader(),
                  Expanded(
                    child: ListView(
                      padding: const .fromLTRB(16, 0, 16, 32),
                      children: [
                        Padding(
                          padding: const .fromLTRB(4, 2, 4, 16),
                          child: Text(
                            context.l10n.settingsTitle,
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: .w700,
                              letterSpacing: -0.6,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        SettingsGroup(
                          children: [
                            BlocBuilder<LanguageCubit, AppLanguage>(
                              bloc: getIt<LanguageCubit>(),
                              builder: (context, language) => SettingsRow(
                                iconPath: AppAssets.palette,
                                hue: TileHue.appearance,
                                title: context.l10n.appearanceTitle,
                                subtitle: appearanceSubtitle(
                                  context.l10n,
                                  layout: layout,
                                  language: language,
                                ),
                                value: themeState.mode.label(context.l10n),
                                showChevron: true,
                                onTap: () =>
                                    context.push('/settings/appearance'),
                              ),
                            ),
                          ],
                        ),
                        SectionHeader(context.l10n.sectionConnection),
                        SettingsGroup(
                          children: [
                            if (isAutoConnectSupported(defaultTargetPlatform))
                              BlocBuilder<AutoConnectCubit, bool>(
                                bloc: getIt<AutoConnectCubit>(),
                                builder: (context, enabled) => SettingsRow(
                                  iconPath: AppAssets.bolt,
                                  hue: TileHue.auto,
                                  title: context.l10n.autoConnectTitle,
                                  subtitle: autoConnectSubtitle(
                                    context.l10n,
                                    enabled: enabled,
                                  ),
                                  switchValue: enabled,
                                  onSwitch: (value) => getIt<AutoConnectCubit>()
                                      .setEnabled(enabled: value),
                                ),
                              ),
                            const _RoutingRow(),
                            BlocBuilder<PingCubit, PingViewState>(
                              bloc: getIt<PingCubit>(),
                              builder: (context, ping) => SettingsRow(
                                iconPath: AppAssets.ping,
                                hue: TileHue.speed,
                                title: context.l10n.pingTitle,
                                subtitle: _pingSubtitle(
                                  context.l10n,
                                  getIt<PingSettingsStore>()
                                      .loadPingOnAppStart(),
                                  ping,
                                ),
                                showChevron: true,
                                onTap: () => context.push('/settings/ping'),
                              ),
                            ),
                            BlocBuilder<
                              SubscriptionAutoUpdateCubit,
                              AutoUpdateInterval
                            >(
                              bloc: getIt<SubscriptionAutoUpdateCubit>(),
                              builder: (context, autoUpdate) => SettingsRow(
                                iconPath: AppAssets.refresh,
                                hue: TileHue.teal,
                                title: context.l10n.subscriptionsTitle,
                                subtitle:
                                    context.l10n.settingsSubscriptionsSubtitle,
                                value: autoUpdate.label(context.l10n),
                                showChevron: true,
                                onTap: () =>
                                    context.push('/settings/subscriptions'),
                              ),
                            ),
                            if (isSplitTunnelSupported(defaultTargetPlatform))
                              BlocBuilder<
                                SplitTunnelCubit,
                                SplitTunnelSettings
                              >(
                                bloc: getIt<SplitTunnelCubit>(),
                                builder: (context, split) => SettingsRow(
                                  iconPath: AppAssets.split,
                                  hue: TileHue.split,
                                  title: context.l10n.splitTitle,
                                  subtitle: context.l10n.settingsSplitSubtitle,
                                  value: splitTunnelSummary(context.l10n, split),
                                  showChevron: true,
                                  onTap: () => context.push('/settings/split'),
                                ),
                              ),
                            if (isSecuritySupported(defaultTargetPlatform))
                              SettingsRow(
                                iconPath: AppAssets.shield,
                                hue: TileHue.security,
                                title: context.l10n.securityTitle,
                                subtitle: context.l10n.settingsSecuritySubtitle,
                                showChevron: true,
                                onTap: () => context.push('/settings/security'),
                              ),
                            const _DnsRow(),
                          ],
                        ),
                        SectionHeader(context.l10n.sectionGeneral),
                        SettingsGroup(
                          children: [
                            SettingsRow(
                              iconPath: AppAssets.backup,
                              hue: TileHue.backup,
                              title: context.l10n.backupTitle,
                              subtitle: context.l10n.settingsBackupSubtitle,
                              showChevron: true,
                              onTap: () => context.push('/settings/backup'),
                            ),
                            SettingsRow(
                              iconPath: AppAssets.bell,
                              hue: TileHue.notif,
                              title: context.l10n.notificationsTitle,
                              subtitle:
                                  context.l10n.settingsNotificationsSubtitle,
                              switchValue: false,
                              enabled: false,
                            ),
                          ],
                        ),
                        SectionHeader(context.l10n.sectionDiagnostics),
                        SettingsGroup(
                          children: [
                            BlocBuilder<MemoryMonitorCubit, MemoryMonitorMode>(
                              bloc: getIt<MemoryMonitorCubit>(),
                              builder: (context, mode) => SettingsRow(
                                iconPath: AppAssets.memory,
                                hue: TileHue.amber,
                                title: context.l10n.memoryMonitorTitle,
                                subtitle: Platform.isIOS
                                    ? context.l10n.settingsMemoryIosSubtitle
                                    : context.l10n.settingsMemorySubtitle,
                                switchValue: mode.enabled,
                                onSwitch: (enabled) =>
                                    getIt<MemoryMonitorCubit>().setEnabled(
                                      enabled: enabled,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        SectionHeader(context.l10n.sectionAbout),
                        SettingsGroup(
                          children: [
                            SettingsRow(
                              iconPath: AppAssets.logs,
                              hue: TileHue.logs,
                              title: context.l10n.logsTitle,
                              subtitle: context.l10n.settingsLogsSubtitle,
                              showChevron: true,
                              onTap: () => context.push('/logs'),
                            ),
                            // The in-app updater installs APKs: a tap checks
                            // for updates on Android only.
                            _VersionRow(
                              colors: colors,
                              onTap: Platform.isAndroid
                                  ? _checkForUpdates
                                  : null,
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
        },
      ),
    );
  }

  static String _pingSubtitle(
    AppLocalizations l10n,
    bool pingOnAppStart,
    PingViewState ping,
  ) {
    final parts = [
      pingOnAppStart ? l10n.pingSummaryOnLaunch : l10n.pingSummaryManual,
      ping.sortByPing ? l10n.pingSummarySorted : l10n.pingSummaryUnsorted,
      ping.displayMode == PingDisplayMode.dots
          ? l10n.pingSummaryDots
          : l10n.pingSummaryNumbers,
    ];
    return parts.join(' · ');
  }
}

class _DnsRow extends StatelessWidget {
  const _DnsRow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DnsCubit, DnsSettings>(
      bloc: getIt<DnsCubit>(),
      builder: (context, dns) => SettingsRow(
        iconPath: AppAssets.globe,
        hue: TileHue.dns,
        title: context.l10n.dnsTitle,
        subtitle: dnsSummary(context.l10n, dns),
        showChevron: true,
        onTap: () => context.push('/settings/dns'),
      ),
    );
  }
}

class _RoutingRow extends StatelessWidget {
  const _RoutingRow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RuBypassCubit, RuBypassMode>(
      bloc: getIt<RuBypassCubit>(),
      builder: (context, ruBypass) => BlocBuilder<AdBlockCubit, AdBlockMode>(
        bloc: getIt<AdBlockCubit>(),
        builder: (context, adBlock) =>
            BlocBuilder<CustomRulesCubit, List<CustomRule>>(
              bloc: getIt<CustomRulesCubit>(),
              builder: (context, rules) => BlocBuilder<GeoCubit, GeoState>(
                bloc: getIt<GeoCubit>(),
                builder: (context, geo) => SettingsRow(
                  iconPath: AppAssets.routing,
                  hue: TileHue.routing,
                  title: context.l10n.routingTitle,
                  subtitle: routingSummary(
                    context.l10n,
                    ruBypass: ruBypass,
                    adBlock: adBlock,
                    customRules: rules.length,
                    geo: geo,
                  ),
                  showChevron: true,
                  onTap: () => context.push('/settings/routing'),
                ),
              ),
            ),
      ),
    );
  }
}

/// The spinner and "CHECKING" that stand in for the version while the app
/// asks GitHub for a newer release.
class _CheckingBadge extends StatelessWidget {
  const _CheckingBadge({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: .min,
      spacing: 7,
      children: [
        SizedBox.square(
          dimension: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.8,
            color: colors.accentIcon,
            backgroundColor: colors.border,
          ),
        ),
        Text(
          context.l10n.versionChecking,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: .w600,
            letterSpacing: 0.8,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Xray core version under the title, app version on the right. The app
/// version comes from the Android updater API, so iOS shows only Xray.
/// With [onTap] the row checks for updates, and "CHECKING" replaces the app
/// version while the check runs.
class _VersionRow extends StatefulWidget {
  const _VersionRow({required this.colors, this.onTap});

  final AppColors colors;
  final VoidCallback? onTap;

  @override
  State<_VersionRow> createState() => _VersionRowState();
}

class _VersionRowState extends State<_VersionRow> {
  // Loaded once, not on every rebuild of the settings page.
  late final Future<(String?, String)> _versions = () async {
    final app = Platform.isAndroid
        ? await getIt<UpdateInstaller>().getAppVersion()
        : null;
    final xray = await getIt<VpnConnection>().xrayCoreVersion();
    return (app == null ? null : '${app.version} (${app.buildNumber})', xray);
  }();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(String?, String)>(
      future: _versions,
      builder: (context, snapshot) {
        final (appVersion, xrayVersion) = snapshot.data ?? (null, null);
        return SettingsRow(
          iconPath: AppAssets.version,
          hue: TileHue.version,
          title: context.l10n.versionTitle,
          subtitle: snapshot.hasError
              ? context.l10n.versionUnavailable
              : xrayVersion == null
              ? '…'
              : widget.onTap == null
              ? context.l10n.versionSubtitle(xrayVersion)
              : context.l10n.versionSubtitleTap(xrayVersion),
          onTap: widget.onTap,
          trailing: BlocBuilder<UpdateServiceCubit, UpdateState>(
            bloc: getIt<UpdateServiceCubit>(),
            builder: (context, update) {
              final checking = update.maybeWhen(
                checking: () => true,
                orElse: () => false,
              );
              if (checking) return _CheckingBadge(colors: widget.colors);
              if (appVersion == null) return const SizedBox.shrink();
              return Text(
                appVersion,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: .w600,
                  color: widget.colors.accentIcon,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
