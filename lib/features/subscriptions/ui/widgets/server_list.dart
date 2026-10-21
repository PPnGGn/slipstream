import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/app_theme.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/core/ui/widgets/accent_button.dart';
import 'package:slipstream/features/ping/presentation/ping_cubit.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';
import 'package:slipstream/features/subscriptions/ui/widgets/server_list/subscription_section.dart';

class ServerList extends StatelessWidget {
  const ServerList({
    super.key,
    this.query = '',
    this.onAddSubscription,
    this.footer,
  });

  final String query;
  final VoidCallback? onAddSubscription;

  /// Shown after the last subscription (the compact layout's add buttons).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppThemeCubit, AppThemeState>(
      bloc: getIt<AppThemeCubit>(),
      builder: (context, _) {
        final colors = getIt<AppColors>();

        return BlocBuilder<SubscriptionsCubit, SubscriptionsState>(
          bloc: getIt<SubscriptionsCubit>(),
          builder: (context, state) {
            if (state.subscriptions.isEmpty) {
              return SingleChildScrollView(
                child: _EmptyState(colors: colors, onAdd: onAddSubscription),
              );
            }

            final normalizedQuery = query.trim().toLowerCase();

            // Pull-to-refresh pings the current (selected) subscription
            // — the spec's first trigger; a full-list run happens on
            // app start and via the per-subscription ping button.
            return RefreshIndicator(
              onRefresh: () {
                final current = state.subscriptions.firstWhere(
                  (s) => s.subscription.id == state.selectedSubscriptionId,
                  orElse: () => state.subscriptions.first,
                );
                return getIt<PingCubit>().runForServers(current.servers);
              },
              child: SingleChildScrollView(
                padding: const .only(bottom: 28),
                child: Column(
                  spacing: AppDims.gapM,
                  children: [
                    for (final stored in state.subscriptions)
                      SubscriptionSection(
                        key: ValueKey(stored.subscription.id),
                        colors: colors,
                        stored: stored,
                        query: normalizedQuery,
                        refreshing: state.refreshingIds.contains(
                          stored.subscription.id,
                        ),
                        selectedServerId:
                            state.selectedSubscriptionId ==
                                stored.subscription.id
                            ? state.selectedServerId
                            : null,
                        onSelect: (server) => getIt<SubscriptionsCubit>()
                            .selectServer(stored.subscription.id, server.id),
                      ),
                    ?footer,
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors, required this.onAdd});

  final AppColors colors;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 20, vertical: 44),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: .center,
            decoration: BoxDecoration(
              shape: .circle,
              color: colors.surface,
              border: .all(color: colors.border),
            ),
            child: SvgPicture.asset(
              AppAssets.cloudOff,
              width: 30,
              height: 30,
              colorFilter: .mode(colors.textSecondary, .srcIn),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No subscriptions yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: .w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add a subscription link or a single server URI —\n'
            'https://, vless://, ss://, trojan:// or raw JSON.',
            textAlign: .center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.55,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          AccentButton(
            label: 'Add subscription',
            onPressed: onAdd,
            height: 44,
            radius: 14,
            fontSize: 13.5,
          ),
        ],
      ),
    );
  }
}
