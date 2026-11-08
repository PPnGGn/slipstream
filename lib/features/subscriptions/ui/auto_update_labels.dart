import 'package:slipstream/features/subscriptions/data/auto_update/auto_update_interval.dart';
import 'package:slipstream/l10n/l10n_context.dart';

extension AutoUpdateIntervalLabels on AutoUpdateInterval {
  String label(AppLocalizations l10n) => switch (hours) {
    null => l10n.commonOff,
    1 => l10n.autoUpdateEveryHour,
    final h => l10n.autoUpdateEveryHours(h),
  };
}
