import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/ui/widgets/page_header.dart';
import 'package:slipstream/core/ui/widgets/segmented_pill.dart';
import 'package:slipstream/features/settings/ui/widgets/reconnect_hint.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_row.dart';
import 'package:slipstream/features/split_tunnel/cubit/installed_apps_cubit.dart';
import 'package:slipstream/features/split_tunnel/cubit/split_tunnel_cubit.dart';
import 'package:slipstream/features/split_tunnel/data/app_filter.dart';
import 'package:slipstream/features/split_tunnel/data/installed_apps_api.g.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_mode.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_settings.dart';
import 'package:slipstream/features/split_tunnel/ui/split_tunnel_labels.dart';
import 'package:slipstream/features/split_tunnel/ui/widgets/app_selection_row.dart';
import 'package:slipstream/features/subscriptions/ui/widgets/subscription_search_bar.dart';

/// Settings → Split tunneling (Android): which apps go through the tunnel and
/// which connect directly. The choice lives in [SplitTunnelCubit] and applies
/// on the next connection; the list of installed apps is this page's own
/// [InstalledAppsCubit].
class SplitTunnelingPage extends StatefulWidget {
  const SplitTunnelingPage({super.key});

  @override
  State<SplitTunnelingPage> createState() => _SplitTunnelingPageState();
}

class _SplitTunnelingPageState extends State<SplitTunnelingPage> {
  final _split = getIt<SplitTunnelCubit>();
  final _vpn = getIt<VpnServiceCubit>();
  final _apps = getIt<InstalledAppsCubit>();
  final _search = TextEditingController();

  // Fixed on entry: picking an app must not make its row jump to the top.
  late final Set<String> _pinned = {..._split.state.packages};

  @override
  void initState() {
    super.initState();
    _search.addListener(() => _apps.setQuery(_search.text));
    _apps.load();
  }

  @override
  void dispose() {
    _search.dispose();
    _apps.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PageHeader(title: 'Split tunneling'),
            Expanded(
              child: BlocBuilder<SplitTunnelCubit, SplitTunnelSettings>(
                bloc: _split,
                builder: (context, settings) =>
                    BlocBuilder<InstalledAppsCubit, InstalledAppsState>(
                      bloc: _apps,
                      builder: (context, apps) => CustomScrollView(
                        slivers: [
                          _controls(context, settings, apps),
                          ..._appList(context, settings, apps),
                        ],
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls(
    BuildContext context,
    SplitTunnelSettings settings,
    InstalledAppsState apps,
  ) {
    final colors = AppColors.of(context);
    final shown = _shown(settings, apps);

    return SliverPadding(
      padding: const .fromLTRB(20, 6, 20, 0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          SettingsGroup(
            children: [
              SettingsRow(
                iconPath: AppAssets.split,
                hue: TileHue.split,
                title: 'Split tunneling',
                subtitle: splitTunnelSummary(settings),
                switchValue: settings.enabled,
                onSwitch: (enabled) {
                  _split.setEnabled(enabled: enabled);
                  notifyIfTunnelActive(context, _vpn);
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          SegmentedPill<SplitTunnelMode>(
            options: const [
              (SplitTunnelMode.proxy, 'Proxy selected'),
              (SplitTunnelMode.bypass, 'Bypass selected'),
            ],
            selected: settings.mode,
            onChanged: (mode) {
              _split.setMode(mode);
              notifyIfTunnelActive(context, _vpn);
            },
          ),
          Padding(
            padding: const .fromLTRB(2, 8, 2, 12),
            child: Text(
              splitTunnelHint(settings.mode),
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: colors.textMuted,
              ),
            ),
          ),
          SettingsGroup(
            children: [
              SettingsRow(
                iconPath: AppAssets.sysApps,
                hue: TileHue.slate,
                title: 'Include system apps',
                subtitle: 'WebView, Play Services and other services',
                switchValue: settings.includeSystem,
                onSwitch: (include) => _split.setIncludeSystem(include: include),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SubscriptionSearchBar(
            colors: colors,
            controller: _search,
            hintText: 'Search apps',
          ),
          if (shown != null)
            SectionHeader(
              splitTunnelCounter(
                selected: shown
                    .where((a) => settings.packages.contains(a.packageName))
                    .length,
                total: shown.length,
                mode: settings.mode,
              ),
              top: 18,
            )
          else
            const SizedBox(height: 18),
        ]),
      ),
    );
  }

  List<Widget> _appList(
    BuildContext context,
    SplitTunnelSettings settings,
    InstalledAppsState apps,
  ) {
    final colors = AppColors.of(context);
    final shown = _shown(settings, apps);

    if (apps is InstalledAppsFailed) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const .symmetric(horizontal: 20, vertical: 28),
            child: Column(
              spacing: 10,
              children: [
                Text(
                  'Could not load the app list',
                  style: TextStyle(fontSize: 12.5, color: colors.textMuted),
                ),
                TextButton(onPressed: _apps.load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ];
    }

    if (shown == null) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: .symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      ];
    }

    if (shown.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const .symmetric(horizontal: 20, vertical: 28),
            child: Text(
              'No apps found',
              textAlign: .center,
              style: TextStyle(fontSize: 12.5, color: colors.textMuted),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const .fromLTRB(20, 0, 20, 28),
        sliver: DecoratedSliver(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: .circular(20),
            border: .all(color: colors.border),
          ),
          sliver: SliverList.builder(
            itemCount: shown.length,
            itemBuilder: (context, index) {
              final app = shown[index];
              return AppSelectionRow(
                key: ValueKey(app.packageName),
                app: app,
                showDivider: index > 0,
                selected: settings.packages.contains(app.packageName),
                loadIcon: _apps.iconFor,
                onChanged: (selected) {
                  _split.setAppSelected(app.packageName, selected: selected);
                  notifyIfTunnelActive(context, _vpn);
                },
              );
            },
          ),
        ),
      ),
    ];
  }

  List<InstalledAppMessage>? _shown(
    SplitTunnelSettings settings,
    InstalledAppsState apps,
  ) => apps is InstalledAppsLoaded
      ? selectedFirst(visibleApps(apps.apps, settings, apps.query), _pinned)
      : null;
}
