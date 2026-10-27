import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/ui/toast/show_toast.dart';
import 'package:slipstream/core/ui/widgets/page_header.dart';
import 'package:slipstream/core/ui/widgets/segmented_pill.dart';
import 'package:slipstream/features/geo/cubit/geo_cubit.dart';
import 'package:slipstream/features/geo/data/geo_update_service.dart';
import 'package:slipstream/features/geo/presentation/geo_update_toast.dart';
import 'package:slipstream/features/routing/cubit/ad_block_cubit.dart';
import 'package:slipstream/features/routing/cubit/ru_bypass_cubit.dart';
import 'package:slipstream/features/routing/data/ad_block_mode.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';
import 'package:slipstream/features/settings/ui/widgets/help_sheet.dart';
import 'package:slipstream/features/settings/ui/widgets/reconnect_hint.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_row.dart';

class RoutingSettingsPage extends StatelessWidget {
  const RoutingSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ruBypassCubit = getIt<RuBypassCubit>();
    final adBlockCubit = getIt<AdBlockCubit>();
    final geoCubit = getIt<GeoCubit>();
    final geoService = getIt<GeoUpdateService>();
    final vpn = getIt<VpnServiceCubit>();
    final colors = AppColors.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Routing',
              actions: [
                BoxIconButton(
                  iconPath: AppAssets.info,
                  onTap: () => _showHelp(context, adBlockCubit),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const .fromLTRB(20, 6, 20, 28),
                children: [
                  // Not built yet: the app always works like Smart.
                  const SegmentedPill<String>(
                    options: [
                      ('global', 'Global'),
                      ('smart', 'Smart'),
                      ('direct', 'Direct'),
                    ],
                    selected: 'smart',
                    onChanged: null,
                  ),
                  Padding(
                    padding: const .fromLTRB(2, 8, 2, 0),
                    child: Text(
                      'Rules decide per domain/IP: matched → direct or block, '
                      'everything else → tunnel.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                  const SectionHeader('Rule profiles', top: 18),
                  SettingsGroup(
                    children: [
                      BlocBuilder<RuBypassCubit, RuBypassMode>(
                        bloc: ruBypassCubit,
                        builder: (context, mode) => SettingsRow(
                          iconPath: AppAssets.pin,
                          hue: TileHue.blue,
                          title: 'Обход РФ',
                          subtitle: 'geosite:ru + geoip:ru → напрямую',
                          switchValue: mode == RuBypassMode.bypassRu,
                          onSwitch: (enabled) async {
                            await ruBypassCubit.setBypassRu(enabled: enabled);
                            notifyIfTunnelActive(vpn);
                          },
                        ),
                      ),
                      BlocBuilder<AdBlockCubit, AdBlockMode>(
                        bloc: adBlockCubit,
                        builder: (context, mode) => SettingsRow(
                          iconPath: AppAssets.block,
                          hue: TileHue.red,
                          title: 'Блокировка рекламы и трекеров',
                          subtitle: mode.enabled
                              ? '${mode.token} → блокировка'
                              : 'Выключена',
                          switchValue: mode.enabled,
                          onSwitch: (enabled) async {
                            await adBlockCubit.setEnabled(enabled: enabled);
                            notifyIfTunnelActive(vpn);
                          },
                          footer: mode.enabled && adBlockCubit.fullAllowed
                              ? SegmentedPill<AdBlockMode>(
                                  options: const [
                                    (AdBlockMode.basic, 'Базовая'),
                                    (AdBlockMode.full, 'Полная'),
                                  ],
                                  selected: mode,
                                  onChanged: (value) async {
                                    await adBlockCubit.setMode(value);
                                    notifyIfTunnelActive(vpn);
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SettingsRow(
                        iconPath: AppAssets.home,
                        hue: TileHue.teal,
                        title: 'Обход LAN',
                        subtitle: '192.168/16 · 10/8 · localhost → напрямую',
                        switchValue: false,
                        enabled: false,
                      ),
                      BlocBuilder<GeoCubit, GeoState>(
                        bloc: geoCubit,
                        builder: (context, state) =>
                            _geoRow(context, state, colors, geoService),
                      ),
                    ],
                  ),
                  const SectionHeader('Custom rules', top: 18),
                  const SettingsGroup(
                    children: [
                      SettingsRow(
                        iconPath: AppAssets.plus,
                        hue: TileHue.slate,
                        title: 'Add rule',
                        subtitle: 'Domain or IP → proxy, direct or block',
                        enabled: false,
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
  }

  static Widget _geoRow(
    BuildContext context,
    GeoState state,
    AppColors colors,
    GeoUpdateService geoService,
  ) {
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
        _Action('Обновить', () => _update(geoService)),
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

    return SettingsRow(
      iconPath: AppAssets.database,
      hue: TileHue.indigo,
      title: 'Гео-базы (geosite / geoip)',
      subtitle: status,
      subtitleStyle: TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        fontWeight: .w500,
        color: state is GeoFailed ? colors.danger : null,
      ),
      trailing: action == null
          ? null
          : _ChipButton(
              colors: colors,
              label: action.label,
              onTap: () => action.onPressed(),
            ),
      footer: state is GeoDownloading
          ? ClipRRect(
              borderRadius: .circular(2),
              child: LinearProgressIndicator(
                value: state.fraction,
                minHeight: 3,
                backgroundColor: colors.chip,
              ),
            )
          : null,
    );
  }

  static void _showHelp(BuildContext context, AdBlockCubit adBlockCubit) {
    showHelpSheet(
      context,
      title: 'Routing',
      entries: [
        const HelpEntry(
          title: 'RU bypass',
          body:
              'Sent directly, bypassing the VPN: .ru and .рф domains, '
              'Russian services and IP addresses, local network, '
              'torrents. All other traffic goes through the VPN.',
        ),
        HelpEntry(
          title: 'Ad blocking',
          body: adBlockCubit.fullAllowed
              ? 'Basic — major ad and tracking networks '
                    '(~830 domains).\n'
                    'Full — extended list (~150,000 domains). Higher '
                    'memory use, possible false positives.'
              : 'Major ad and tracking networks (~830 domains). The '
                    'extended list does not fit the memory limit of '
                    'the iOS VPN extension.',
        ),
        const HelpEntry(
          title: 'Geo databases',
          body:
              'Domain and IP lists used by the rules above. '
              'Downloaded separately from the app, updated manually.\n'
              'Without them ads are not blocked, and RU bypass covers '
              'only .ru and .рф.',
        ),
        const HelpEntry(
          title: 'When applied',
          body:
              'Changes take effect on reconnect.\n'
              'Not applied to servers whose config has its own '
              'routing rules (set by the VPN provider).',
        ),
      ],
    );
  }

  static Future<void> _update(GeoUpdateService service) async {
    final outcome = await service.updateNow();
    showToastSpec(geoUpdateToast(outcome));
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _Action {
  const _Action(this.label, this.onPressed);
  final String label;
  final Future<void> Function() onPressed;
}

/// Small bordered chip button with a refresh icon (geo bases row).
class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.colors,
    required this.label,
    required this.onTap,
  });

  final AppColors colors;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: .opaque,
      child: Container(
        height: 32,
        padding: const .symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: colors.chip,
          borderRadius: .circular(10),
          border: .all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: .min,
          spacing: 6,
          children: [
            SvgPicture.asset(
              AppAssets.refresh,
              width: 12,
              height: 12,
              colorFilter: .mode(colors.textPrimary, .srcIn),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: .w600,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
