import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/core/utils/formatters.dart';

/// The mono line under a subscription's name:
/// `7 SERVERS · UPD 21.07.2026 14:03 · EVERY 12H`, or `UPDATING…` while a
/// refresh is running.
String subscriptionMetaLine(
  Subscription subscription, {
  required int serverCount,
  required bool refreshing,
}) {
  if (refreshing) return 'UPDATING…';

  final interval = subscription.updateIntervalHours;
  return [
    '$serverCount ${serverCount == 1 ? 'SERVER' : 'SERVERS'}',
    'UPD ${formatUpdatedAt(subscription.lastUpdatedAt)}',
    if (subscription.url == null)
      'MANUAL'
    else if (interval != null)
      'EVERY ${interval}H',
  ].join(' · ');
}
