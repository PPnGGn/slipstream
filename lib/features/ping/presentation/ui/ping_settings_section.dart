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
            title: 'Ping on launch',
            subtitle: 'Measure all servers on start and on return',
            switchValue: _pingOnAppStart,
            onSwitch: (enabled) {
              setState(() => _pingOnAppStart = enabled);
              getIt<PingSettingsStore>().savePingOnAppStart(enabled);
            },
          ),
          SettingsRow(
            iconPath: AppAssets.arrowDown,
            hue: TileHue.violet,
            title: 'Sort servers by latency',
            subtitle: 'Reorders the list after measuring finishes',
            switchValue: view.sortByPing,
            onSwitch: getIt<PingCubit>().setSortByPing,
          ),
          SettingsRow(
            iconPath: AppAssets.ping,
            hue: TileHue.teal,
            title: 'Latency display',
            subtitle: 'Colored dot or value in the server list',
            footer: SegmentedPill<PingDisplayMode>(
              options: const [
                (PingDisplayMode.numbers, 'Numbers'),
                (PingDisplayMode.dots, 'Dots'),
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
