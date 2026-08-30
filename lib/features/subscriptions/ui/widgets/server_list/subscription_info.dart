import 'package:flutter/material.dart';
import 'package:slipstream/core/utils/formatters.dart';
import 'package:slipstream/core/models/subscription/subscription.dart';
import 'package:slipstream/core/theme/app_colors.dart';

/// Always-visible block under the section header: days left, traffic, announce,
/// update timestamp. Does not collapse with the servers.
class SubscriptionInfo extends StatelessWidget {
  const SubscriptionInfo({
    super.key,
    required this.colors,
    required this.subscription,
    required this.serverCount,
  });

  final AppColors colors;
  final Subscription subscription;
  final int serverCount;

  @override
  Widget build(BuildContext context) {
    final used = subscription.usedBytes;
    final expiresAt = subscription.expiresAt;
    final announce = subscription.announce?.trim();
    final hasAnnounce = announce != null && announce.isNotEmpty;

    final metaStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 10,
      fontWeight: .w600,
      letterSpacing: 0.3,
      color: colors.textMuted,
    );

    final daysLeft = expiresAt?.difference(DateTime.now()).inDays;

    return Padding(
      padding: const .fromLTRB(14, 0, 14, 12),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          if (used != null || daysLeft != null) ...[
            Row(
              spacing: 10,
              children: [
                if (daysLeft != null)
                  Text(
                    daysLeft > 0 ? '${daysLeft}d left' : 'expired',
                    style: metaStyle.copyWith(
                      color: daysLeft <= 3 ? colors.warn : colors.textMuted,
                    ),
                  ),
                if (used != null)
                  Expanded(
                    child: _TrafficBar(
                      colors: colors,
                      used: used,
                      limit: subscription.dataLimitBytes,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (hasAnnounce)
            Text(
              announce,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: colors.textSecondary,
              ),
            ),
          const SizedBox(height: 10),
          Align(
            alignment: .centerRight,
            child: Text(
              '${formatUpdatedAt(subscription.lastUpdatedAt)}  ·  $serverCount',
              style: metaStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrafficBar extends StatelessWidget {
  const _TrafficBar({
    required this.colors,
    required this.used,
    required this.limit,
  });

  final AppColors colors;
  final int used;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final unlimited = limit == null || limit! <= 0;
    final ratio = unlimited ? 0.0 : (used / limit!).clamp(0.0, 1.0);
    final label = unlimited
        ? '${formatBytes(used)} / ∞'
        : '${formatBytes(used)} / ${formatBytes(limit!)}';

    return Container(
      height: 22,
      clipBehavior: .antiAlias,
      decoration: BoxDecoration(
        color: colors.inputFill,
        borderRadius: .circular(7),
        border: .all(color: colors.border),
      ),
      child: Stack(
        children: [
          if (!unlimited)
            FractionallySizedBox(
              widthFactor: ratio,
              heightFactor: 1,
              child: ColoredBox(color: colors.primary.withValues(alpha: 0.25)),
            ),
          Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: .w600,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
