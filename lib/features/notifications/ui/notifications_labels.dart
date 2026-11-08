import 'package:slipstream/features/notifications/data/notification_prefs.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// The value of the Notifications row in Settings. The system switch wins:
/// with notifications blocked for the app, no setting of ours shows anything.
String notificationsSummary(
  AppLocalizations l10n,
  NotificationPrefs prefs, {
  required bool allowed,
}) {
  if (!allowed) return l10n.notificationsSummaryBlocked;
  return switch ((prefs.trafficBlocked, prefs.startFailed)) {
    (true, true) => l10n.notificationsSummaryAll,
    (false, false) => l10n.commonOff,
    _ => l10n.notificationsSummaryOne,
  };
}
