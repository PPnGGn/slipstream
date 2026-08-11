import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/app/theme.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';
import 'package:slipstream/features/subscriptions/ui/add_subscription_dialog.dart';
import 'package:slipstream/features/subscriptions/ui/widgets/empty_subscriptions.dart';
import 'package:slipstream/features/subscriptions/ui/widgets/subscription_card.dart';
import 'package:slipstream/features/vpn/cubit/vpn_cubit.dart';
import 'package:slipstream/features/vpn/ui/widgets/connection_status.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final vpnCubit = getIt<VpnCubit>();
    final subsCubit = getIt<SubscriptionsCubit>();

    return Scaffold(
      backgroundColor: AppColors.gray10,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Slipstream'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Логи',
            onPressed: () => context.push('/logs'),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Добавить подписку',
            onPressed: () => showAddSubscriptionDialog(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.gray10,
          image: DecorationImage(
            image: AssetImage('assets/png/background_map.png'),
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              BlocBuilder<SubscriptionsCubit, SubscriptionsState>(
                bloc: subsCubit,
                builder: (context, subsState) {
                  return BlocBuilder<VpnCubit, VpnState>(
                    bloc: vpnCubit,
                    builder: (context, vpnState) {
                      return ConnectionArea(
                        vpnState: vpnState,
                        selectedServer: subsState.selectedServer,
                        hasSubscriptions: subsState.subscriptions.isNotEmpty,
                        onConnect: () {
                          final server = subsState.selectedServer;
                          if (server != null) vpnCubit.connect(server);
                        },
                        onDisconnect: vpnCubit.disconnect,
                      );
                    },
                  );
                },
              ),
              Expanded(
                child: BlocBuilder<SubscriptionsCubit, SubscriptionsState>(
                  bloc: subsCubit,
                  builder: (context, subsState) {
                    if (subsState.subscriptions.isEmpty) {
                      return const EmptySubscriptions();
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        for (final stored in subsState.subscriptions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SubscriptionCard(
                              stored: stored,
                              selectedServerId:
                                  subsState.selectedSubscriptionId ==
                                      stored.subscription.id
                                  ? subsState.selectedServerId
                                  : null,
                              isRefreshing: subsState.refreshingIds.contains(
                                stored.subscription.id,
                              ),
                              onSelect: (server) {
                                subsCubit.selectServer(
                                  stored.subscription.id,
                                  server.id,
                                );
                                vpnCubit.switchServerIfActive(server);
                              },
                              onDelete: () => subsCubit.removeSubscription(
                                stored.subscription.id,
                              ),
                              onRefresh: stored.subscription.url == null
                                  ? null
                                  : () => subsCubit.refreshSubscription(
                                      stored.subscription.id,
                                    ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
