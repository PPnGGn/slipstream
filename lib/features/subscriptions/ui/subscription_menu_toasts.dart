import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/features/subscriptions/cubit/refresh_outcome.dart';
import 'package:slipstream/features/subscriptions/ui/add_subscription_toasts.dart';
import 'package:slipstream/l10n/l10n_context.dart';

// What the subscription's ⋯ menu says about its actions, as toasts.

/// The toast for a manual refresh; null when nothing happened (see
/// [RefreshIgnored]).
ToastSpec? refreshToast(AppLocalizations l10n, RefreshOutcome outcome) =>
    switch (outcome) {
      Refreshed(:final subscription) => ToastSpec(
        l10n.subUpdatedTitle,
        subtitle:
            '${l10n.serverCountUpper(subscription.servers.length)} · '
            '${subscription.subscription.name.toUpperCase()}',
      ),
      RefreshFailed(:final cause) => subscriptionFailedToast(
        l10n,
        cause,
        fallbackTitle: l10n.refreshFailedTitle,
      ),
      RefreshIgnored() => null,
    };

/// The toast for the list's pull down, which refreshes every URL
/// subscription at once. One subscription reads like [refreshToast]; for
/// several it sums up, and each failed one is marked in its own header.
ToastSpec? refreshAllToast(
  AppLocalizations l10n,
  List<RefreshOutcome> outcomes,
) {
  final done = outcomes.where((o) => o is! RefreshIgnored).toList();
  if (done.isEmpty) return null;
  if (done.length == 1) return refreshToast(l10n, done.single);

  final failed = done.whereType<RefreshFailed>().length;
  if (failed > 0) {
    return ToastSpec(
      l10n.refreshSomeFailedTitle(failed, done.length),
      subtitle: l10n.refreshSomeFailedHint,
      kind: ToastKind.error,
    );
  }
  final servers = done.whereType<Refreshed>().fold(
    0,
    (sum, r) => sum + r.subscription.servers.length,
  );
  return ToastSpec(
    l10n.subsUpdatedTitle,
    subtitle:
        '${l10n.subscriptionCountUpper(done.length)} · '
        '${l10n.serverCountUpper(servers)}',
  );
}

ToastSpec subscriptionDeletedToast(AppLocalizations l10n, String name) =>
    ToastSpec(l10n.subDeletedTitle, subtitle: name.toUpperCase());
