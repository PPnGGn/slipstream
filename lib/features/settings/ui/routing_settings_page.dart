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
import 'package:slipstream/features/help/ui/help_button.dart';
import 'package:slipstream/features/help/ui/help_topics.dart';
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
import 'package:slipstream/features/routing/ui/routing_labels.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';
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
                HelpButton(
                  topic: () =>
                      routingHelp(fullAdBlockAllowed: adBlockCubit.fullAllowed),
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
                          title: 'RU bypass',
                          subtitle: 'geosite:ru + geoip:ru → direct',
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
                          title: 'Ad & tracker blocking',
                          subtitle: mode.enabled
                              ? '${mode.token} → block'
                              : 'Off',
                          switchValue: mode.enabled,
                          onSwitch: (enabled) async {
                            await adBlockCubit.setEnabled(enabled: enabled);
                            notifyIfTunnelActive(vpn);
                          },
                          footer: mode.enabled && adBlockCubit.fullAllowed
                              ? SegmentedPill<AdBlockMode>(
                                  options: const [
                                    (AdBlockMode.basic, 'Basic'),
                                    (AdBlockMode.full, 'Full'),
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
                          title: 'LAN bypass',
                          subtitle: '192.168/16 · 10/8 · localhost → direct',
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
    final label = geoActionLabel(state);
    final Future<void> Function()? onAction = switch (state) {
      GeoAbsent() ||
      GeoUpdateAvailable() ||
      GeoFailed() => () => geoService.downloadNow(),
      GeoReady() => () => _update(geoService),
      _ => null,
    };

    return SettingsRow(
      iconPath: AppAssets.database,
      hue: TileHue.indigo,
      title: 'Geo databases (geosite / geoip)',
      subtitle: geoStatusText(state),
      subtitleStyle: TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        fontWeight: .w500,
        color: state is GeoFailed ? colors.danger : null,
      ),
      trailing: label == null || onAction == null
          ? null
          : _ChipButton(colors: colors, label: label, onTap: () => onAction()),
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
