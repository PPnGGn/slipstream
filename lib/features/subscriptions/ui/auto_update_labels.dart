import 'package:slipstream/features/subscriptions/data/auto_update/auto_update_interval.dart';

extension AutoUpdateIntervalLabels on AutoUpdateInterval {
  String get label => switch (hours) {
    null => 'Off',
    1 => 'Every hour',
    final h => 'Every $h hours',
  };
}
