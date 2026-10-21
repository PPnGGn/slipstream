import 'dart:ui';

import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/features/vpn/presentation/connection_status_view.dart';

extension ConnectionPhaseColors on ConnectionPhase {
  /// Status color; null while off — each widget picks its own neutral.
  Color? accent(AppColors colors) => switch (this) {
    ConnectionPhase.off => null,
    ConnectionPhase.busy => colors.warn,
    ConnectionPhase.on => colors.ok,
    ConnectionPhase.error => colors.danger,
  };
}
