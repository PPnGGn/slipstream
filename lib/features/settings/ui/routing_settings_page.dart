import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/app_theme.dart';
import 'package:slipstream/features/geo/cubit/geo_cubit.dart';
import 'package:slipstream/features/geo/data/geo_update_service.dart';
import 'package:slipstream/features/routing/cubit/ad_block_cubit.dart';
import 'package:slipstream/features/routing/cubit/ru_bypass_cubit.dart';
import 'package:slipstream/features/routing/data/ad_block_mode.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';

/// Settings page for the client's own routing policy: RU-bypass, ad-block and
/// the geo databases (geosite.dat / geoip.dat) both of them run on.
class RoutingSettingsPage extends StatelessWidget {
  const RoutingSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ruBypassCubit = getIt<RuBypassCubit>();
    final adBlockCubit = getIt<AdBlockCubit>();
    final geoCubit = getIt<GeoCubit>();
    final geoService = getIt<GeoUpdateService>();
    final vpn = getIt<VpnServiceCubit>();
    final colors = getIt<AppColors>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Правила маршрутизации')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDims.horizontalPadding,
          AppDims.gapS,
          AppDims.horizontalPadding,
          AppDims.gapXxl,
        ),
        children: [
          BlocBuilder<RuBypassCubit, RuBypassMode>(
            bloc: ruBypassCubit,
            builder: (context, mode) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Обход РФ'),
              value: mode == RuBypassMode.bypassRu,
              onChanged: (enabled) async {
                await ruBypassCubit.setBypassRu(enabled: enabled);
                if (context.mounted) _notifyIfConnected(context, vpn);
              },
            ),
          ),
          const SizedBox(height: AppDims.gapXxl),
          _Heading('Блокировка рекламы', textTheme: textTheme, colors: colors),
          const SizedBox(height: AppDims.gapS),
          BlocBuilder<AdBlockCubit, AdBlockMode>(
            bloc: adBlockCubit,
            builder: (context, mode) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final option in AdBlockMode.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_adBlockLabel(option)),
                    trailing: option == mode
                        ? const Icon(Icons.check)
                        : const SizedBox.shrink(),
                    onTap: () async {
                      await adBlockCubit.setMode(option);
                      if (context.mounted) _notifyIfConnected(context, vpn);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppDims.gapXxl),
          BlocBuilder<GeoCubit, GeoState>(
            bloc: geoCubit,
            builder: (context, state) {
              final (String status, _Action? action) = switch (state) {
                GeoAbsent() => (
                  'Не загружены',
                  _Action('Загрузить', () => geoService.downloadNow()),
                ),
                GeoChecking() => ('Проверка обновлений…', null),
                GeoDownloading(:final fraction) => (
                  'Загрузка… ${(fraction * 100).round()}%',
                  null,
                ),
                GeoReady(:final tag, :final updatedAt) => (
                  'Актуально · $tag · ${_date(updatedAt)}',
                  _Action('Обновить', () => _update(context, geoService)),
                ),
                GeoUpdateAvailable(:final latestTag) => (
                  'Доступно обновление: $latestTag',
                  _Action('Обновить', () => geoService.downloadNow()),
                ),
                GeoFailed(:final message) => (
                  message,
                  _Action('Повторить', () => geoService.downloadNow()),
                ),
                _ => ('', null),
              };

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Гео-базы (geosite / geoip)'),
                    subtitle: Text(
                      status,
                      style: textTheme.labelMedium?.copyWith(
                        color: state is GeoFailed
                            ? colors.danger
                            : colors.textSecondary,
                      ),
                    ),
                    trailing: action == null
                        ? null
                        : TextButton(
                            onPressed: () => action.onPressed(),
                            child: Text(action.label),
                          ),
                  ),
                  if (state is GeoDownloading)
                    Padding(
                      padding: const EdgeInsets.only(top: AppDims.gapS),
                      child: LinearProgressIndicator(value: state.fraction),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _adBlockLabel(AdBlockMode mode) => switch (mode) {
    AdBlockMode.off => 'Выключена',
    AdBlockMode.basic => 'Базовая',
    AdBlockMode.full => 'Полная',
  };

  static Future<void> _update(
    BuildContext context,
    GeoUpdateService service,
  ) async {
    final outcome = await service.updateNow();
    if (!context.mounted) return;
    final text = switch (outcome) {
      GeoUpdateOutcome.updated => 'Базы обновлены',
      GeoUpdateOutcome.upToDate => 'Уже актуально',
      GeoUpdateOutcome.failed => 'Не удалось проверить обновление',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  void _notifyIfConnected(BuildContext context, VpnServiceCubit vpn) {
    final active = vpn.state.maybeWhen(
      connected: (_, _, _, _) => true,
      connecting: () => true,
      orElse: () => false,
    );
    if (!active) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Применится при переподключении')),
      );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {required this.textTheme, required this.colors});

  final String text;
  final TextTheme textTheme;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: textTheme.titleSmall?.copyWith(color: colors.textPrimary),
    );
  }
}

class _Action {
  const _Action(this.label, this.onPressed);
  final String label;
  final Future<void> Function() onPressed;
}
