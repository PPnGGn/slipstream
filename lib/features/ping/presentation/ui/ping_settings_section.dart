import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/ui/widgets/segmented_pill.dart';
import 'package:slipstream/features/ping/data/ping_settings_store.dart';
import 'package:slipstream/features/ping/presentation/ping_cubit.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_row.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// Ping feature settings (spec's last checklist item): display mode,
/// the app-start trigger toggle and the sort-by-latency toggle.
class PingSettingsSection extends StatefulWidget {
  const PingSettingsSection({super.key});

  @override
  State<PingSettingsSection> createState() => _PingSettingsSectionState();
}

class _PingSettingsSectionState extends State<PingSettingsSection> {
  late bool _pingOnAppStart = getIt<PingSettingsStore>().loadPingOnAppStart();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PingCubit, PingViewState>(
      bloc: getIt<PingCubit>(),
      builder: (context, view) => SettingsGroup(
        children: [
          SettingsRow(
            iconPath: AppAssets.bolt,
            hue: TileHue.speed,
            title: context.l10n.pingOnLaunchTitle,
            subtitle: context.l10n.pingOnLaunchSubtitle,
            switchValue: _pingOnAppStart,
            onSwitch: (enabled) {
              setState(() => _pingOnAppStart = enabled);
              getIt<PingSettingsStore>().savePingOnAppStart(enabled);
            },
          ),
          SettingsRow(
            iconPath: AppAssets.arrowDown,
            hue: TileHue.violet,
            title: context.l10n.pingSortTitle,
            subtitle: context.l10n.pingSortSubtitle,
            switchValue: view.sortByPing,
            onSwitch: getIt<PingCubit>().setSortByPing,
          ),
          SettingsRow(
            iconPath: AppAssets.ping,
            hue: TileHue.teal,
            title: context.l10n.pingDisplayTitle,
            subtitle: context.l10n.pingDisplaySubtitle,
            footer: SegmentedPill<PingDisplayMode>(
              options: [
                (PingDisplayMode.numbers, context.l10n.pingDisplayNumbers),
                (PingDisplayMode.dots, context.l10n.pingDisplayDots),
              ],
              selected: view.displayMode,
              onChanged: getIt<PingCubit>().setDisplayMode,
            ),
          ),
        ],
      ),
    );
  }
}
