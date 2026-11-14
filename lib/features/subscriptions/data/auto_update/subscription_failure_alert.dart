import 'package:slipstream/core/models/subscription/subscription.dart';

/// What the background job does about the alert "subscription did not update"
/// after one refresh.
enum FailureAlertAction { none, show, cancel }

/// Decides it from the subscription as it was stored ([before]) and as the
/// refresh left it ([after]).
///
/// The job retries a failing subscription every half hour, so an alert at every
/// failure would be a stream of them. It alerts when a run of failures starts:
/// [after] failed and [before] has no `failureNotifiedAt`. The job stores that
/// time with the failure, so the later failures of the same run find it and stay
/// quiet. A refresh that worked ends the run, and the alert, which would
/// otherwise outlive the problem, is taken back.
///
/// Only the job asks: in the app a failed refresh is already on the screen.
FailureAlertAction failureAlertAction({
  required Subscription before,
  required Subscription after,
  required bool enabled,
}) {
  final inRun = before.failureNotifiedAt != null;
  if (after.lastError != null) {
    return !inRun && enabled ? .show : .none;
  }
  // The switch may have been turned off while the alert showed: it still
  // goes, whatever the switch says now.
  return inRun ? .cancel : .none;
}
