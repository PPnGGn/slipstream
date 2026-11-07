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
import 'package:slipstream/features/routing/cubit/custom_rules_cubit.dart';
import 'package:slipstream/features/routing/cubit/lan_bypass_cubit.dart';
import 'package:slipstream/features/routing/cubit/ru_bypass_cubit.dart';
import 'package:slipstream/features/routing/data/ad_block_mode.dart';
import 'package:slipstream/features/routing/data/custom_rule.dart';
import 'package:slipstream/features/routing/data/routing_applies.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';
import 'package:slipstream/features/routing/ui/custom_rule_labels.dart';
import 'package:slipstream/features/routing/ui/custom_rule_sheet.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';
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
    final lanBypassCubit = getIt<LanBypassCubit>();
    final customRulesCubit = getIt<CustomRulesCubit>();
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
                  BlocBuilder<SubscriptionsCubit, SubscriptionsState>(
                    bloc: getIt<SubscriptionsCubit>(),
                    buildWhen: (a, b) =>
                        routingAppliesTo(a.selectedServer) !=
                        routingAppliesTo(b.selectedServer),
                    builder: (context, state) =>
                        routingAppliesTo(state.selectedServer)
                        ? const SizedBox.shrink()
                        : const _OwnRoutingNotice(),
                  ),
                  const SectionHeader('Rule profiles', top: 4),
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
                      BlocBuilder<LanBypassCubit, bool>(
                        bloc: lanBypassCubit,
                        builder: (context, enabled) => SettingsRow(
                          iconPath: AppAssets.home,
                          hue: TileHue.teal,
                          title: 'Обход LAN',
                          subtitle: '192.168/16 · 10/8 · localhost → напрямую',
                          switchValue: enabled,
                          onSwitch: (value) async {
                            await lanBypassCubit.setEnabled(enabled: value);
                            notifyIfTunnelActive(vpn);
                          },
                        ),
                      ),
                      BlocBuilder<GeoCubit, GeoState>(
                        bloc: geoCubit,
                        builder: (context, state) =>
                            _geoRow(context, state, colors, geoService),
                      ),
                    ],
                  ),
                  const SectionHeader('Custom rules', top: 18),
                  BlocBuilder<CustomRulesCubit, List<CustomRule>>(
                    bloc: customRulesCubit,
                    builder: (context, rules) => SettingsGroup(
                      children: [
                        for (final rule in rules)
                          SettingsRow(
                            iconPath: _ruleIcon(rule.action),
                            hue: _ruleHue(rule.action),
                            title: rule.value,
                            subtitle: ruleKindLabel(rule),
                            trailing: Text(
                              ruleActionTitle(rule.action).toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                fontWeight: .w700,
                                letterSpacing: 1,
                                color: colors.textMuted,
                              ),
                            ),
                            onTap: () =>
                                showCustomRuleSheet(context, rule: rule),
                          ),
                        SettingsRow(
                          iconPath: AppAssets.plus,
                          hue: TileHue.slate,
                          title: 'Add rule',
                          subtitle: 'Domain or IP → proxy, direct or block',
                          onTap: () => showCustomRuleSheet(context),
                        ),
                      ],
                    ),
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
              'Russian services and IP addresses, torrents. All other '
              'traffic goes through the VPN.',
        ),
        const HelpEntry(
          title: 'LAN bypass',
          body:
              'Traffic to your local network (router, printer, NAS, '
              'Chromecast, localhost) is sent directly. Keep it on: '
              'with it off, those devices go through the VPN server and '
              'usually stop being found.',
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
          title: 'Custom rules',
          body:
              'Your own rules for a domain (with its subdomains) or an IP '
              'address or range. Proxy sends it through the VPN, Direct '
              'sends it bypassing the VPN, Block drops it.\n'
              'The most specific rule wins: mail.google.com beats '
              'google.com. Your rules come before RU bypass, ad blocking '
              'and LAN bypass.',
        ),
        const HelpEntry(
          title: 'When applied',
          body:
              'Changes take effect on reconnect.\n'
              'Servers whose config has its own routing rules (set by '
              'the VPN provider or your panel) keep them: RU bypass, ad '
              'blocking and LAN bypass do not apply to them. Custom rules '
              'do, and stand ahead of the server\'s own.',
        ),
      ],
    );
  }

  static String _ruleIcon(RuleAction action) => switch (action) {
    RuleAction.proxy => AppAssets.shield,
    RuleAction.direct => AppAssets.arrowRight,
    RuleAction.block => AppAssets.block,
  };

  static TileHue _ruleHue(RuleAction action) => switch (action) {
    RuleAction.proxy => TileHue.blue,
    RuleAction.direct => TileHue.teal,
    RuleAction.block => TileHue.red,
  };

  static Future<void> _update(GeoUpdateService service) async {
    final outcome = await service.updateNow();
    showToastSpec(geoUpdateToast(outcome));
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

/// Shown while the selected server has a routing of its own: the switches
/// and rules below do not act on it.
class _OwnRoutingNotice extends StatelessWidget {
  const _OwnRoutingNotice();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const .only(bottom: 14),
      padding: const .all(12),
      decoration: BoxDecoration(
        color: colors.chip,
        borderRadius: .circular(14),
        border: .all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: .start,
        spacing: 10,
        children: [
          SvgPicture.asset(
            AppAssets.info,
            width: 15,
            height: 15,
            colorFilter: .mode(colors.textMuted, .srcIn),
          ),
          Expanded(
            child: Text(
              routingOwnConfigNotice,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
