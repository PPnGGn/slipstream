import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/update_service/update_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
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
import 'package:slipstream/features/update/data/updater_api.g.dart';
import 'package:slipstream/features/update/ui/widgets/update_dialog.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _updateCubit = getIt<UpdateServiceCubit>();

  Future<void> _checkForUpdates() async {
    final alreadyReady = _updateCubit.state.maybeWhen(
      readyToInstall: (_, _) => true,
      orElse: () => false,
    );
    if (alreadyReady) {
      await showUpdateDialog(context);
      return;
    }

    final alreadyDownloading = _updateCubit.state.maybeWhen(
      downloading: (_, _) => true,
      orElse: () => false,
    );
    if (alreadyDownloading) {
      _showSnack('Downloading update…');
      return;
    }

    await _updateCubit.check(userInitiated: true);
    if (!mounted) return;

    await _updateCubit.state.when(
      idle: () async {},
      checking: () async {},
      upToDate: () async => _showSnack("You're up to date"),
      downloading: (_, _) async => _showSnack('Downloading update…'),
      readyToInstall: (_, _) => showUpdateDialog(context),
      signatureConflict: (_, _) => showUpdateDialog(context),
      error: (message) async => _showSnack(message),
    );
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
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
                            const SettingsRow(
                              iconPath: AppAssets.split,
                              hue: TileHue.split,
                              title: 'Split tunneling',
                              subtitle: 'Choose which apps use the tunnel',
                              showChevron: true,
                              enabled: false,
                            ),
                            const SettingsRow(
                              iconPath: AppAssets.shield,
                              hue: TileHue.security,
                              title: 'Security & tunnel',
                              subtitle:
                                  'Kill switch, Always-On VPN, LAN access',
                              showChevron: true,
                              enabled: false,
                            ),
                            const SettingsRow(
                              iconPath: AppAssets.globe,
                              hue: TileHue.dns,
                              title: 'DNS',
                              subtitle: 'Queries resolved through the tunnel',
                              showChevron: true,
                              enabled: false,
                            ),
                          ],
                        ),
                        const SectionHeader('General'),
                        const SettingsGroup(
                          children: [
                            SettingsRow(
                              iconPath: AppAssets.backup,
                              hue: TileHue.backup,
                              title: 'Backup & restore',
                              subtitle: 'Encrypted file, QR or deep link',
                              showChevron: true,
                              enabled: false,
                            ),
                            SettingsRow(
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
                              enabled: false,
                            ),
                          ],
                        ),
                        const SectionHeader('About'),
                        SettingsGroup(
                          children: [
                            // Turned on in 1.2.6 together with release logs
                            // (releases.md); the /logs page already exists.
                            const SettingsRow(
                              iconPath: AppAssets.logs,
                              hue: TileHue.logs,
                              title: 'Xray core logs',
                              subtitle: 'Live tunnel output',
                              showChevron: true,
                              enabled: false,
                            ),
                            if (Platform.isAndroid)
                              _VersionRow(
                                colors: colors,
                                onTap: _checkForUpdates,
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

/// App version on the right, Xray version under the title; tap checks for
/// updates. Android only: the versions come from Android platform APIs.
class _VersionRow extends StatefulWidget {
  const _VersionRow({required this.colors, required this.onTap});

  final AppColors colors;
  final VoidCallback onTap;

  @override
  State<_VersionRow> createState() => _VersionRowState();
}

class _VersionRowState extends State<_VersionRow> {
  // Loaded once, not on every rebuild of the settings page.
  late final Future<(AppVersionMessage, String)> _versions = () async {
    final app = await getIt<UpdateInstaller>().getAppVersion();
    final xray = await getIt<VpnConnection>().xrayCoreVersion();
    return (app, xray);
  }();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(AppVersionMessage, String)>(
      future: _versions,
      builder: (context, snapshot) {
        final versions = snapshot.data;
        return SettingsRow(
          iconPath: AppAssets.version,
          hue: TileHue.version,
          title: 'Version',
          subtitle: versions == null ? '…' : 'Xray ${versions.$2}',
          trailing: Text(
            versions == null
                ? ''
                : '${versions.$1.version} (${versions.$1.buildNumber})',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: .w600,
              color: widget.colors.accentIcon,
            ),
          ),
          onTap: widget.onTap,
        );
      },
    );
  }
}
