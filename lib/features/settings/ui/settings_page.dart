import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/update_service/update_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/app_theme.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
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
    await _updateCubit.check();
    if (!mounted) return;

    await _updateCubit.state.when(
      idle: () async {},
      checking: () async {},
      available: (_) => showUpdateDialog(context),
      upToDate: () async => _showSnack("You're up to date"),
      downloading: (_, _) async {},
      readyToInstall: (_, _) async {},
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
            padding: const .symmetric(horizontal: AppDims.horizontalPadding),
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
            ],
          ),
        );
      },
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
          info != null ? '${info.version} (${info.buildNumber})' : '…',
          style: textTheme.labelMedium?.copyWith(color: colors.textSecondary),
        );
      },
    );
  }
}
