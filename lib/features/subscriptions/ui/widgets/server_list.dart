import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/theme/app_theme.dart';
import 'package:slipstream/core/theme/cubit/theme_cubit.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';
import 'package:slipstream/features/subscriptions/ui/widgets/server_list/subscription_section.dart';

class ServerList extends StatelessWidget {
  const ServerList({super.key, this.query = '', this.onAddSubscription});

  final String query;
  final VoidCallback? onAddSubscription;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppThemeCubit, AppThemeMode>(
      bloc: getIt<AppThemeCubit>(),
      builder: (context, _) {
        final colors = getIt<AppColors>();

        return BlocBuilder<SubscriptionsCubit, SubscriptionsState>(
          bloc: getIt<SubscriptionsCubit>(),
          builder: (context, state) {
            if (state.subscriptions.isEmpty) {
              return _EmptyState(onAdd: onAddSubscription);
            }

            final normalizedQuery = query.trim().toLowerCase();

            return SingleChildScrollView(
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
                          state.selectedSubscriptionId == stored.subscription.id
                          ? state.selectedServerId
                          : null,
                      onSelect: (server) => getIt<SubscriptionsCubit>()
                          .selectServer(stored.subscription.id, server.id),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton(
        onPressed: onAdd,
        child: const Text('Add subscription'),
      ),
    );
  }
}
