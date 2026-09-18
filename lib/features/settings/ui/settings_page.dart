import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/update_service/update_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/app_theme.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/features/diagnostics/cubit/memory_monitor_cubit.dart';
import 'package:slipstream/features/diagnostics/data/memory_monitor_mode.dart';
import 'package:slipstream/features/geo/cubit/geo_cubit.dart';
import 'package:slipstream/features/routing/cubit/ad_block_cubit.dart';
import 'package:slipstream/features/routing/cubit/ru_bypass_cubit.dart';
import 'package:slipstream/features/routing/data/ad_block_mode.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';
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
    final themeCubit = getIt<AppThemeCubit>();

    return BlocBuilder<AppThemeCubit, AppThemeState>(
      bloc: themeCubit,
      builder: (context, themeState) {
        final colors = getIt<AppColors>();
        final textTheme = Theme.of(context).textTheme;

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppDims.horizontalPadding,
              AppDims.gapS,
              AppDims.horizontalPadding,
              AppDims.gapXxl,
            ),
            children: [
              const SectionHeader('Appearance'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: _ThemeModeSwitch(
                    mode: themeState.mode,
                    isDark: themeState.isDark,
                    colors: colors,
                    onChanged: themeCubit.setMode,
                  ),
                ),
              ),
              const SizedBox(height: AppDims.gapXxl),
              const SectionHeader('Connection'),
              const SizedBox(height: AppDims.gapS),
              SettingsCard(
                children: [
                  const SwitchListTile(
                    title: Text('Auto-connect on launch'),
                    subtitle: Text('Restore last session at startup'),
                    value: true,
                    onChanged: null,
                  ),
                  BlocBuilder<RuBypassCubit, RuBypassMode>(
                    bloc: getIt<RuBypassCubit>(),
                    builder: (context, ruBypass) =>
                        BlocBuilder<AdBlockCubit, AdBlockMode>(
                          bloc: getIt<AdBlockCubit>(),
                          builder: (context, adBlock) =>
                              BlocBuilder<GeoCubit, GeoState>(
                                bloc: getIt<GeoCubit>(),
                                builder: (context, geo) => _NavRow(
                                  title: 'Routing',
                                  subtitle: _routingSubtitle(
                                    ruBypass,
                                    adBlock,
                                    geo,
                                  ),
                                  onTap: () =>
                                      context.push('/settings/routing'),
                                ),
                              ),
                        ),
                  ),
                  const ListTile(
                    enabled: false,
                    title: Text('Split tunneling'),
                    subtitle: Text('Choose which apps use the tunnel'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                  const ListTile(
                    enabled: false,
                    title: Text('Security & tunnel'),
                    subtitle: Text('Kill switch, Always-On VPN, LAN access'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                  const ListTile(
                    enabled: false,
                    title: Text('Speed test'),
                    subtitle: Text('URL-test all servers, pick the fastest'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                  ListTile(
                    enabled: false,
                    title: const Text('DNS'),
                    subtitle: const Text('Queries resolved through the tunnel'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'DoH · CF',
                          style: textTheme.labelMedium?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                        const SizedBox(width: AppDims.gapXs),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDims.gapXxl),
              const SectionHeader('General'),
              const SizedBox(height: AppDims.gapS),
              SettingsCard(
                children: [
                  ListTile(
                    enabled: false,
                    title: const Text('Language'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'English',
                          style: textTheme.labelMedium?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                        const SizedBox(width: AppDims.gapXs),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                  const ListTile(
                    enabled: false,
                    title: Text('Backup & restore'),
                    subtitle: Text('Encrypted file, QR or deep link'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                  const SwitchListTile(
                    title: Text('Notifications'),
                    subtitle: Text('Connection drops & subscription updates'),
                    value: true,
                    onChanged: null,
                  ),
                ],
              ),
              const SizedBox(height: AppDims.gapXxl),
              const SectionHeader('Diagnostics'),
              const SizedBox(height: AppDims.gapS),
              SettingsCard(
                children: [
                  BlocBuilder<MemoryMonitorCubit, MemoryMonitorMode>(
                    bloc: getIt<MemoryMonitorCubit>(),
                    builder: (context, mode) => SwitchListTile(
                      title: const Text('Memory monitor'),
                      subtitle: Text(
                        Platform.isIOS
                            ? 'Tunnel footprint on the home screen · 50 MB limit'
                            : 'Xray-core memory on the home screen',
                      ),
                      value: mode.enabled,
                      onChanged: (enabled) => getIt<MemoryMonitorCubit>()
                          .setEnabled(enabled: enabled),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDims.gapXxl),
              const SectionHeader('About'),
              const SizedBox(height: AppDims.gapS),
              SettingsCard(
                children: [
                  const ListTile(
                    enabled: false,
                    title: Text('Xray core logs'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                  if (Platform.isAndroid)
                    ListTile(
                      title: const Text('Version'),
                      trailing: _AppVersionText(
                        colors: colors,
                        textTheme: textTheme,
                      ),
                      onTap: _checkForUpdates,
                    ),
                ],
              ),
            ],
          ),
        );
      },
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

class _ThemeModeSwitch extends StatelessWidget {
  const _ThemeModeSwitch({
    required this.mode,
    required this.isDark,
    required this.colors,
    required this.onChanged,
  });

  final AppThemeMode mode;
  final bool isDark;
  final AppColors colors;
  final ValueChanged<AppThemeMode> onChanged;

  static const _options = [
    (AppThemeMode.light, 'Light'),
    (AppThemeMode.dark, 'Dark'),
    (AppThemeMode.system, 'System'),
  ];

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? const Color(0xFF4A4B70) : colors.surfaceRaised;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.chip,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        spacing: 6,
        children: [
          for (final (value, label) in _options)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: mode == value ? activeColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: mode == value
                        ? [
                            BoxShadow(
                              color: const Color.fromRGBO(20, 20, 32, 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      color: mode == value
                          ? colors.textPrimary
                          : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = getIt<AppColors>();
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: textTheme.labelMedium?.copyWith(color: colors.textSecondary),
      ),
      trailing: Icon(Icons.chevron_right, color: colors.textMuted),
      onTap: onTap,
    );
  }
}

class _AppVersionText extends StatelessWidget {
  const _AppVersionText({required this.colors, required this.textTheme});

  final AppColors colors;
  final TextTheme textTheme;

  Future<String> _load() async {
    final appVersion = await getIt<UpdateInstaller>().getAppVersion();
    final xrayVersion = await getIt<VpnConnection>().xrayCoreVersion();
    return '${appVersion.version} · Xray $xrayVersion';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _load(),
      builder: (context, snapshot) {
        return Text(
          snapshot.data ?? '…',
          style: textTheme.labelMedium?.copyWith(
            fontFamily: 'monospace',
            color: colors.textMuted,
          ),
        );
      },
    );
  }
}
