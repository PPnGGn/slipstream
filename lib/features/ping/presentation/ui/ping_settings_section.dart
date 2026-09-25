import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/features/ping/data/ping_settings_store.dart';
import 'package:slipstream/features/ping/presentation/ping_cubit.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';

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
      builder: (context, view) => SettingsCard(
        children: [
          SwitchListTile(
            title: const Text('Ping on launch'),
            subtitle: const Text('Measure all servers when the app starts'),
            value: _pingOnAppStart,
            onChanged: (enabled) {
              setState(() => _pingOnAppStart = enabled);
              getIt<PingSettingsStore>().savePingOnAppStart(enabled);
            },
          ),
          SwitchListTile(
            title: const Text('Sort servers by latency'),
            subtitle: const Text('Reorders the list after measuring finishes'),
            value: view.sortByPing,
            onChanged: getIt<PingCubit>().setSortByPing,
          ),
          ListTile(
            title: const Text('Latency display'),
            subtitle: const Text('Colored dot or value in the server list'),
            trailing: SegmentedButton<PingDisplayMode>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(
                  value: PingDisplayMode.numbers,
                  label: Text('Numbers'),
                ),
                ButtonSegment(value: PingDisplayMode.dots, label: Text('Dots')),
              ],
              selected: {view.displayMode},
              onSelectionChanged: (selection) =>
                  getIt<PingCubit>().setDisplayMode(selection.first),
            ),
          ),
        ],
      ),
    );
  }
}
