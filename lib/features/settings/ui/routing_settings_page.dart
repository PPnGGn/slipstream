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
import 'package:slipstream/features/settings/ui/widgets/help_sheet.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';

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
      appBar: AppBar(
        title: const Text('Routing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'About these settings',
            onPressed: () => showHelpSheet(
              context,
              title: 'Routing',
              entries: const [
                HelpEntry(
                  title: 'RU bypass',
                  body:
                      'Sent directly, bypassing the VPN: .ru and .рф domains, '
                      'Russian services and IP addresses, local network, '
                      'torrents. All other traffic goes through the VPN.',
                ),
                HelpEntry(
                  title: 'Ad blocking',
                  body:
                      'Basic — major ad and tracking networks '
                      '(~830 domains).\n'
                      'Full — extended list (~150,000 domains). Higher memory '
                      'use, possible false positives, may be unstable on iOS.',
                ),
                HelpEntry(
                  title: 'Geo databases',
                  body:
                      'Domain and IP lists used by the rules above. '
                      'Downloaded separately from the app, updated manually.\n'
                      'Without them ads are not blocked, and RU bypass covers '
                      'only .ru and .рф.',
                ),
                HelpEntry(
                  title: 'When applied',
                  body:
                      'Changes take effect on reconnect.\n'
                      'Not applied to servers whose config has its own '
                      'routing rules (set by the VPN provider).',
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDims.horizontalPadding,
          AppDims.gapS,
          AppDims.horizontalPadding,
          AppDims.gapXxl,
        ),
        children: [
          const SectionHeader('Rule profiles'),
          SettingsCard(
            children: [
              BlocBuilder<RuBypassCubit, RuBypassMode>(
                bloc: ruBypassCubit,
                builder: (context, mode) => SwitchListTile(
                  title: const Text('Обход РФ'),
                  subtitle: const Text('geosite:ru + geoip:ru → напрямую'),
                  value: mode == RuBypassMode.bypassRu,
                  onChanged: (enabled) async {
                    await ruBypassCubit.setBypassRu(enabled: enabled);
                    if (context.mounted) _notifyIfConnected(context, vpn);
                  },
                ),
              ),
              BlocBuilder<AdBlockCubit, AdBlockMode>(
                bloc: adBlockCubit,
                builder: (context, mode) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      title: const Text('Блокировка рекламы и трекеров'),
                      subtitle: Text(
                        mode.enabled
                            ? '${mode.token} → блокировка'
                            : 'Выключена',
                      ),
                      value: mode.enabled,
                      onChanged: (enabled) async {
                        await adBlockCubit.setEnabled(enabled: enabled);
                        if (context.mounted) _notifyIfConnected(context, vpn);
                      },
                    ),
                    if (mode.enabled)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          AppDims.gapM,
                        ),
                        child: SegmentedButton<AdBlockMode>(
                          segments: const [
                            ButtonSegment(
                              value: AdBlockMode.basic,
                              label: Text('Базовая'),
                            ),
                            ButtonSegment(
                              value: AdBlockMode.full,
                              label: Text('Полная'),
                            ),
                          ],
                          selected: {mode},
                          showSelectedIcon: false,
                          onSelectionChanged: (selection) async {
                            await adBlockCubit.setMode(selection.first);
                            if (context.mounted) {
                              _notifyIfConnected(context, vpn);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SwitchListTile(
                title: Text('Обход LAN'),
                subtitle: Text('192.168/16 · 10/8 · localhost → напрямую'),
                value: false,
                onChanged: null,
              ),
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
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            AppDims.gapM,
                          ),
                          child: LinearProgressIndicator(value: state.fraction),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

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

class _Action {
  const _Action(this.label, this.onPressed);
  final String label;
  final Future<void> Function() onPressed;
}
