import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/ui/widgets/custom_icon_button.dart';
import 'package:slipstream/features/appearance/cubit/home_layout_cubit.dart';
import 'package:slipstream/features/appearance/data/home_layout.dart';
import 'package:slipstream/features/subscriptions/ui/widgets/add_actions_row.dart';
import 'package:slipstream/features/subscriptions/ui/widgets/add_subscription_sheet.dart';
import 'package:slipstream/features/subscriptions/ui/widgets/server_list.dart';
import 'package:slipstream/features/subscriptions/ui/widgets/subscription_search_bar.dart';
import 'package:slipstream/features/update/data/updater_api.g.dart';
import 'package:slipstream/features/vpn/presentation/connection_status_view.dart';
import 'package:slipstream/features/vpn/ui/widgets/compact_connection_bar.dart';
import 'package:slipstream/features/vpn/ui/widgets/connection_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _addSubscription([AddSheetAction? action]) =>
      showAddSubscriptionSheet(context, initialAction: action);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppThemeCubit, AppThemeState>(
      bloc: getIt<AppThemeCubit>(),
      builder: (context, _) {
        final colors = getIt<AppColors>();

        return BlocBuilder<HomeLayoutCubit, HomeLayout>(
          bloc: getIt<HomeLayoutCubit>(),
          builder: (context, layout) {
            final compact = layout == HomeLayout.compact;

            return Scaffold(
              body: Stack(
                children: [
                  _StatusAura(colors: colors),
                  SafeArea(
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: .stretch,
                      children: [
                        _Header(
                          colors: colors,
                          onAdd: () => _addSubscription(),
                        ),
                        Padding(
                          padding: const .fromLTRB(20, 12, 20, 10),
                          child: SubscriptionSearchBar(
                            colors: colors,
                            controller: _search,
                          ),
                        ),
                        if (!compact)
                          const Padding(
                            padding: .fromLTRB(20, 2, 20, 12),
                            child: ConnectionCard(),
                          ),
                        // The key keeps the list's element (scroll offset,
                        // expanded subscriptions) when the layout switches:
                        // without it the Column re-creates its unkeyed
                        // middle children. See vpn/docs/theme.md.
                        Expanded(
                          key: const ValueKey('server-list'),
                          child: Padding(
                            padding: const .symmetric(horizontal: 20),
                            child: AnimatedBuilder(
                              animation: _search,
                              builder: (context, _) => ServerList(
                                query: _search.text,
                                onAddSubscription: _addSubscription,
                                footer: compact
                                    ? AddActionsRow(
                                        onAdd: _addSubscription,
                                        onPaste: () => _addSubscription(
                                          AddSheetAction.paste,
                                        ),
                                        onScan: () => _addSubscription(
                                          AddSheetAction.scan,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        if (compact) const CompactConnectionBar(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.colors, required this.onAdd});

  final AppColors colors;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .fromLTRB(20, 10, 20, 2),
      child: Row(
        spacing: 10,
        children: [
          CustomIconButton(
            onTap: () => context.push('/settings'),
            iconPath: AppAssets.wave,
            size: 30,
            radius: 9,
            iconSize: 16,
            iconColor: colors.ink,
            gradientColors: colors.brandGradient,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: .baseline,
              textBaseline: .alphabetic,
              spacing: 7,
              children: [
                Text(
                  'SlipStream',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: .w700,
                    letterSpacing: -0.34,
                    color: colors.textPrimary,
                  ),
                ),
                if (Platform.isAndroid) _AppVersion(colors: colors),
              ],
            ),
          ),
          CustomIconButton(
            onTap: onAdd,
            iconPath: AppAssets.plus,
            size: 34,
            radius: 11,
            iconSize: 15,
            iconColor: colors.ink,
            gradientColors: colors.brandGradient,
          ),
        ],
      ),
    );
  }
}

/// "v2.0.0" next to the title. Android only: the version comes from the
/// updater's platform API, which iOS doesn't implement.
class _AppVersion extends StatefulWidget {
  const _AppVersion({required this.colors});

  final AppColors colors;

  @override
  State<_AppVersion> createState() => _AppVersionState();
}

class _AppVersionState extends State<_AppVersion> {
  late final Future<AppVersionMessage> _version = getIt<UpdateInstaller>()
      .getAppVersion();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppVersionMessage>(
      future: _version,
      builder: (context, snapshot) => Text(
        snapshot.hasData ? 'v${snapshot.data!.version}' : '',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10.5,
          fontWeight: .w500,
          color: widget.colors.textMuted,
        ),
      ),
    );
  }
}

/// Soft radial glow behind the header, tinted by the connection status.
class _StatusAura extends StatelessWidget {
  const _StatusAura({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VpnServiceCubit, VpnState>(
      bloc: getIt<VpnServiceCubit>(),
      builder: (context, state) {
        final color = switch (connectionPhaseOf(state)) {
          ConnectionPhase.on => colors.auraOn,
          ConnectionPhase.busy => colors.warn.withValues(alpha: 0.14),
          ConnectionPhase.error => colors.danger.withValues(alpha: 0.14),
          ConnectionPhase.off => colors.auraOff,
        };
        // Design: opacity .6 on the whole glow.
        final tint = color.withValues(alpha: color.a * 0.6);

        return Positioned(
          top: -160,
          left: 0,
          right: 0,
          height: 440,
          child: IgnorePointer(
            child: OverflowBox(
              maxWidth: 540,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                width: 540,
                height: 440,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [tint, tint.withValues(alpha: 0)],
                    stops: const [0, 0.72],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
