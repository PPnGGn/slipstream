import 'package:slipstream/core/ui/toast/show_toast.dart';
import 'package:slipstream/features/ping/presentation/ping_cubit.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';
import 'package:slipstream/features/subscriptions/ui/subscription_menu_toasts.dart';

/// The server list's pull down: re-fetches every URL subscription and pings
/// the ones without a URL, which have nothing to fetch. Refreshed
/// subscriptions are not pinged here: `PingAutoRunner` pings them as soon as
/// their `lastUpdatedAt` changes. Completes when both are over, so the
/// indicator spins for as long as something runs.
Future<void> pullToRefresh(
  SubscriptionsCubit subscriptions,
  PingCubit ping,
) async {
  final local = [
    for (final stored in subscriptions.state.subscriptions)
      if (stored.subscription.url == null) ...stored.servers,
  ];
  final pinging = local.isEmpty ? null : ping.runForServers(local);

  final toast = refreshAllToast(await subscriptions.refreshAll());
  if (toast != null) showToastSpec(toast);
  await pinging;
}
