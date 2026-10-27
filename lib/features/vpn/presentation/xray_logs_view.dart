import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';

/// What the Xray logs page says and decides, away from the widget: the page
/// only draws these values.

/// The chips above the log: which levels are shown.
enum LogLevelFilter {
  all('ALL'),
  info('INFO'),
  warn('WARN'),
  error('ERROR');

  const LogLevelFilter(this.label);

  final String label;
}

/// The color class of a line. Unknown levels read as plain info.
enum LogSeverity { error, warn, debug, info }

LogSeverity logSeverityOf(String level) => switch (level.toLowerCase()) {
  'error' => LogSeverity.error,
  'warning' || 'warn' => LogSeverity.warn,
  'debug' => LogSeverity.debug,
  _ => LogSeverity.info,
};

bool _matches(String level, LogLevelFilter filter) {
  final lower = level.toLowerCase();
  return switch (filter) {
    LogLevelFilter.all => true,
    LogLevelFilter.info => lower == 'info',
    LogLevelFilter.warn => lower == 'warning' || lower == 'warn',
    LogLevelFilter.error => lower == 'error',
  };
}

List<VpnLogMessage> filterLogs(
  List<VpnLogMessage> logs,
  LogLevelFilter filter,
) => [
  for (final log in logs)
    if (_matches(log.level, filter)) log,
];

/// "WARN" for a warning, otherwise the level in caps.
String logLevelLabel(String level) => switch (level.toLowerCase()) {
  'warning' => 'WARN',
  final other => other.toUpperCase(),
};

/// The device's time of a line, "13:05:09".
String logTimeOf(int timestampMs) {
  final t = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// What Copy puts on the clipboard: one line per log. The source (xray,
/// tun2socks, …) is not drawn on the page but stays here, because a pasted
/// log goes to someone who is looking for the cause.
String logsAsText(List<VpnLogMessage> logs) => [
  for (final log in logs)
    '${logTimeOf(log.timestampMs)} [${logLevelLabel(log.level)}] '
        '${log.message} · ${log.source}',
].join('\n');

/// The line under the log: "FOLLOWING · 14 LINES · TUNNEL UP". [following]
/// is false once the user has scrolled up and the view stopped sticking to
/// the newest line.
String logsStatusLine({
  required int lines,
  required bool tunnelUp,
  required bool following,
}) {
  final mode = following ? 'FOLLOWING' : 'PAUSED';
  final tunnel = tunnelUp ? 'TUNNEL UP' : 'TUNNEL DOWN';
  return '$mode · ${_lineCount(lines)} · $tunnel';
}

/// What the empty log box says: where logs come from, or that the filter
/// hides everything there is.
String logsEmptyText({required int total, required LogLevelFilter filter}) =>
    total == 0
    ? 'Logs appear while the tunnel runs'
    : 'No ${filter.label} lines';

String _lineCount(int lines) => lines == 1 ? '1 LINE' : '$lines LINES';

/// The toast after Copy; [lines] is how many lines went to the clipboard.
ToastSpec logsCopyToast(int lines) => lines == 0
    ? const ToastSpec(
        'Nothing to copy',
        subtitle: 'NO LOG LINES YET',
        kind: ToastKind.info,
      )
    : ToastSpec('Logs copied', subtitle: '${_lineCount(lines)} · PLAIN TEXT');

bool isTunnelUp(VpnState state) =>
    state.maybeWhen(connected: (_, _, _, _) => true, orElse: () => false);
