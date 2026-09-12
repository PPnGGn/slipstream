import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/update_service/update_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/app_theme.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/features/geo/cubit/geo_cubit.dart';
import 'package:slipstream/features/routing/cubit/ad_block_cubit.dart';
import 'package:slipstream/features/routing/cubit/ru_bypass_cubit.dart';
import 'package:slipstream/features/routing/data/ad_block_mode.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';
import 'package:slipstream/features/update/data/updater_api.g.dart';
import 'package:slipstream/features/update/ui/widgets/update_dialog.dart';

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
    return BlocBuilder<AppThemeCubit, AppThemeMode>(
      bloc: getIt<AppThemeCubit>(),
      builder: (context, _) {
        final colors = getIt<AppColors>();
        final textTheme = Theme.of(context).textTheme;

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDims.horizontalPadding,
            ),
            children: [
              if (Platform.isAndroid)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('App version'),
                  subtitle: _AppVersionText(
                    colors: colors,
                    textTheme: textTheme,
                  ),
                  trailing: TextButton(
                    onPressed: _checkForUpdates,
                    child: const Text('Check for updates'),
                  ),
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
                              title: 'Правила маршрутизации',
                              subtitle: _routingSubtitle(
                                ruBypass,
                                adBlock,
                                geo,
                              ),
                              onTap: () => context.push('/settings/routing'),
                            ),
                          ),
                    ),
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
      contentPadding: EdgeInsets.zero,
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppVersionMessage>(
      future: getIt<UpdateInstaller>().getAppVersion(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        return Text(
          info != null ? info.version : '…',
          style: textTheme.labelMedium?.copyWith(color: colors.textSecondary),
        );
      },
    );
  }
}
