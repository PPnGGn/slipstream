import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/core/utils/formatters.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/auto_update_interval.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/subscription_update_policy.dart';

/// The mono line under a subscription's name:
/// `7 SERVERS · UPD 21.07.2026 14:03 · EVERY 12H`, or `UPDATING…` while a
/// refresh is running. The interval is the one auto-update actually uses
/// (the provider's, else [autoUpdate]); `UPDATE FAILED` follows when the
/// last attempt did not get through.
String subscriptionMetaLine(
  Subscription subscription, {
  required int serverCount,
  required bool refreshing,
  required AutoUpdateInterval autoUpdate,
}) {
  if (refreshing) return 'UPDATING…';

  final interval = effectiveUpdateInterval(subscription, autoUpdate);
  return [
    '$serverCount ${serverCount == 1 ? 'SERVER' : 'SERVERS'}',
    'UPD ${formatUpdatedAt(subscription.lastUpdatedAt)}',
    if (subscription.url == null)
      'MANUAL'
    else if (interval == null)
      'AUTO OFF'
    else
      'EVERY ${interval.inHours}H',
    if (subscription.lastError != null) 'UPDATE FAILED',
  ].join(' · ');
}
