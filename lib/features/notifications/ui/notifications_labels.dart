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
  final on = prefs.enabledCount;
  if (on == NotificationPrefs.total) return l10n.notificationsSummaryAll;
  if (on == 0) return l10n.commonOff;
  return l10n.notificationsSummaryCount(on, NotificationPrefs.total);
}
