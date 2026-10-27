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
import 'package:slipstream/features/diagnostics/cubit/memory_monitor_cubit.dart';
import 'package:slipstream/features/diagnostics/data/memory_monitor_mode.dart';
import 'package:slipstream/features/geo/cubit/geo_cubit.dart';
import 'package:slipstream/features/ping/data/ping_settings_store.dart';
import 'package:slipstream/features/ping/presentation/ping_cubit.dart';
import 'package:slipstream/features/routing/cubit/ad_block_cubit.dart';
import 'package:slipstream/features/routing/cubit/ru_bypass_cubit.dart';
import 'package:slipstream/features/routing/data/ad_block_mode.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_row.dart';
import 'package:slipstream/features/split_tunnel/cubit/split_tunnel_cubit.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_settings.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_support.dart';
import 'package:slipstream/features/split_tunnel/ui/split_tunnel_labels.dart';
import 'package:slipstream/features/subscriptions/cubit/subscription_auto_update_cubit.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/auto_update_interval.dart';
import 'package:slipstream/features/subscriptions/ui/auto_update_labels.dart';
import 'package:slipstream/features/update/data/updater_api.g.dart';
import 'package:slipstream/features/update/ui/update_toasts.dart';
import 'package:slipstream/features/update/ui/widgets/update_dialog.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';

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
                            'Settings',
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
                            SettingsRow(
                              iconPath: AppAssets.palette,
                              hue: TileHue.appearance,
                              title: 'Appearance',
                              subtitle: '${layout.label} layout · English',
                              value: themeState.mode.label,
                              showChevron: true,
                              onTap: () => context.push('/settings/appearance'),
                            ),
                          ],
                        ),
                        const SectionHeader('Connection'),
                        SettingsGroup(
                          children: [
                            const SettingsRow(
                              iconPath: AppAssets.bolt,
                              hue: TileHue.auto,
                              title: 'Auto-connect on launch',
                              subtitle: 'Restore last session at startup',
                              switchValue: false,
                              enabled: false,
                            ),
                            const _RoutingRow(),
                            BlocBuilder<PingCubit, PingViewState>(
                              bloc: getIt<PingCubit>(),
                              builder: (context, ping) => SettingsRow(
                                iconPath: AppAssets.ping,
                                hue: TileHue.speed,
                                title: 'Ping',
                                subtitle: _pingSubtitle(
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
                                title: 'Subscriptions',
                                subtitle: 'Auto-update of subscription links',
                                value: autoUpdate.label,
                                showChevron: true,
                                onTap: () =>
                                    context.push('/settings/subscriptions'),
                              ),
                            ),
                            if (isSplitTunnelSupported(defaultTargetPlatform))
                              BlocBuilder<SplitTunnelCubit, SplitTunnelSettings>(
                                bloc: getIt<SplitTunnelCubit>(),
                                builder: (context, split) => SettingsRow(
                                  iconPath: AppAssets.split,
                                  hue: TileHue.split,
                                  title: 'Split tunneling',
                                  subtitle: 'Choose which apps use the tunnel',
                                  value: splitTunnelSummary(split),
                                  showChevron: true,
                                  onTap: () => context.push('/settings/split'),
                                ),
                              ),
                            SettingsRow(
                              iconPath: AppAssets.shield,
                              hue: TileHue.security,
                              title: 'Security & tunnel',
                              subtitle:
                                  'Kill switch, Always-On VPN, LAN access',
                              showChevron: true,
                              onTap: () => context.push('/settings/security'),
                            ),
                            SettingsRow(
                              iconPath: AppAssets.globe,
                              hue: TileHue.dns,
                              title: 'DNS',
                              subtitle: 'Queries resolved through the tunnel',
                              showChevron: true,
                              onTap: () => context.push('/settings/dns'),
                            ),
                          ],
                        ),
                        const SectionHeader('General'),
                        SettingsGroup(
                          children: [
                            SettingsRow(
                              iconPath: AppAssets.backup,
                              hue: TileHue.backup,
                              title: 'Backup & restore',
                              subtitle: 'Encrypted file, QR or deep link',
                              showChevron: true,
                              onTap: () => context.push('/settings/backup'),
                            ),
                            const SettingsRow(
                              iconPath: AppAssets.bell,
                              hue: TileHue.notif,
                              title: 'Notifications',
                              subtitle:
                                  'Connection drops & subscription updates',
                              switchValue: false,
                              enabled: false,
                            ),
                          ],
                        ),
                        const SectionHeader('Diagnostics'),
                        SettingsGroup(
                          children: [
                            BlocBuilder<MemoryMonitorCubit, MemoryMonitorMode>(
                              bloc: getIt<MemoryMonitorCubit>(),
                              builder: (context, mode) => SettingsRow(
                                iconPath: AppAssets.memory,
                                hue: TileHue.amber,
                                title: 'Memory monitor',
                                subtitle: Platform.isIOS
                                    ? 'Tunnel footprint on the home screen · '
                                          '50 MB limit'
                                    : 'Xray-core memory on the home screen',
                                switchValue: mode.enabled,
                                onSwitch: (enabled) =>
                                    getIt<MemoryMonitorCubit>().setEnabled(
                                      enabled: enabled,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SectionHeader('Help'),
                        SettingsGroup(
                          children: [
                            SettingsRow(
                              iconPath: AppAssets.sparkle,
                              hue: TileHue.assistant,
                              title: 'Assistant',
                              subtitle: 'Ask anything about VPN & the app',
                              trailing: _AiBadge(colors: colors),
                              showChevron: true,
                              onTap: () => context.push('/settings/assistant'),
                            ),
                          ],
                        ),
                        const SectionHeader('About'),
                        SettingsGroup(
                          children: [
                            SettingsRow(
                              iconPath: AppAssets.logs,
                              hue: TileHue.logs,
                              title: 'Xray core logs',
                              subtitle: 'Live tunnel output',
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

  static String _pingSubtitle(bool pingOnAppStart, PingViewState ping) {
    final parts = [
      pingOnAppStart ? 'on launch' : 'manual only',
      ping.sortByPing ? 'sorted' : 'unsorted',
      ping.displayMode == PingDisplayMode.dots ? 'dots' : 'numbers',
    ];
    return parts.join(' · ');
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
        builder: (context, adBlock) => BlocBuilder<GeoCubit, GeoState>(
          bloc: getIt<GeoCubit>(),
          builder: (context, geo) => SettingsRow(
            iconPath: AppAssets.routing,
            hue: TileHue.routing,
            title: 'Routing',
            subtitle: _routingSubtitle(ruBypass, adBlock, geo),
            showChevron: true,
            onTap: () => context.push('/settings/routing'),
          ),
        ),
      ),
    );
  }

  static String _routingSubtitle(
    RuBypassMode ruBypass,
    AdBlockMode adBlock,
    GeoState geo,
  ) {
    final parts = [
      ruBypass == RuBypassMode.bypassRu ? 'Обход РФ' : 'Обход РФ выкл',
      switch (adBlock) {
        AdBlockMode.off => 'реклама выкл',
        AdBlockMode.basic => 'реклама: базовая',
        AdBlockMode.full => 'реклама: полная',
      },
      _geoSubtitle(geo),
    ];
    return parts.join(' · ');
  }

  static String _geoSubtitle(GeoState state) => switch (state) {
    GeoAbsent() => 'гео-базы не загружены',
    GeoChecking() => 'проверка гео-баз…',
    GeoDownloading(:final fraction) => 'гео-базы: ${(fraction * 100).round()}%',
    GeoReady() => 'гео-базы актуальны',
    GeoUpdateAvailable() => 'доступно обновление гео-баз',
    GeoFailed() => 'ошибка загрузки гео-баз',
    _ => '',
  };
}

class _AiBadge extends StatelessWidget {
  const _AiBadge({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const .symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: .circular(6),
      ),
      child: Text(
        'AI',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 8.5,
          fontWeight: .w700,
          letterSpacing: 0.7,
          color: colors.accentIcon,
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
          'CHECKING',
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
          title: 'Version',
          subtitle: snapshot.hasError
              ? 'Unavailable'
              : xrayVersion == null
              ? '…'
              : widget.onTap == null
              ? 'Xray $xrayVersion'
              : 'Xray $xrayVersion · Tap to check for updates',
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
