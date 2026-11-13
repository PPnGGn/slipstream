import 'package:slipstream/features/ping/presentation/real_delay_entry.dart';
import 'package:slipstream/l10n/l10n_context.dart';

/// What the result chip of the Real delay row says: the time, or why there is
/// none. Null while there is nothing to show (not checked yet, or running).
/// "ms" stays as it is in the ping pill, see PingPill.
String? realDelayResultText(AppLocalizations l10n, RealDelayEntry entry) =>
    switch (entry.status) {
      RealDelayStatus.measured => '${entry.latencyMs} ms',
      RealDelayStatus.failed => switch (entry.failure) {
        RealDelayFailure.timeout => l10n.realDelayTimeout,
        _ => l10n.realDelayFailed,
      },
      RealDelayStatus.notTested || RealDelayStatus.measuring => null,
    };

String realDelayButtonText(AppLocalizations l10n, RealDelayEntry entry) =>
    switch (entry.status) {
      RealDelayStatus.notTested => l10n.realDelayCheck,
      RealDelayStatus.measuring => l10n.realDelayChecking,
      RealDelayStatus.measured ||
      RealDelayStatus.failed => l10n.realDelayCheckAgain,
    };
