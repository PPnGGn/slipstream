import 'package:slipstream/core/models/stored_subscription/stored_subscription.dart';

/// How a refresh of one subscription ended, for the menu to tell the user.
/// The automatic refresh ignores it: it has no one to tell.
sealed class RefreshOutcome {
  const RefreshOutcome();
}

/// New servers arrived (and were saved).
final class Refreshed extends RefreshOutcome {
  const Refreshed(this.subscription);

  final StoredSubscription subscription;
}

/// The fetch failed; the old servers stay. [cause] is the exception type the
/// UI picks its wording from (null when none was recorded).
final class RefreshFailed extends RefreshOutcome {
  const RefreshFailed(this.cause);

  final Object? cause;
}

/// Nothing was done: unknown id, no URL to fetch, a refresh of the same
/// subscription already running, or it was deleted while fetching.
final class RefreshIgnored extends RefreshOutcome {
  const RefreshIgnored();
}
