import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';
import 'package:slipstream/features/vpn/presentation/xray_logs_view.dart';

VpnLogMessage _log(
  String level,
  String message, {
  String source = 'xray',
  DateTime? at,
}) => VpnLogMessage(
  level: level,
  message: message,
  source: source,
  timestampMs: (at ?? DateTime(2026, 10, 27, 0, 11, 58)).millisecondsSinceEpoch,
);

void main() {
  final logs = [
    _log('info', 'started'),
    _log('warning', 'dns timeout'),
    _log('error', 'conn refused'),
    _log('debug', 'tick'),
    _log('info', 'stats'),
  ];

  group('filterLogs', () {
    List<String> pick(LogLevelFilter filter) => [
      for (final l in filterLogs(logs, filter)) l.message,
    ];

    test('ALL keeps everything, debug included', () {
      expect(pick(LogLevelFilter.all), [
        'started',
        'dns timeout',
        'conn refused',
        'tick',
        'stats',
      ]);
    });

    test('INFO keeps only info lines', () {
      expect(pick(LogLevelFilter.info), ['started', 'stats']);
    });

    test('WARN keeps both spellings of a warning', () {
      final both = [_log('warning', 'a'), _log('warn', 'b'), _log('info', 'c')];

      expect([
        for (final l in filterLogs(both, LogLevelFilter.warn)) l.message,
      ], ['a', 'b']);
    });

    test('ERROR keeps only errors', () {
      expect(pick(LogLevelFilter.error), ['conn refused']);
    });

    test('the case of the level does not matter', () {
      expect(
        filterLogs([_log('ERROR', 'x')], LogLevelFilter.error),
        hasLength(1),
      );
    });

    test('a level nobody knows is only in ALL', () {
      final odd = [_log('trace', 'x')];

      expect(filterLogs(odd, LogLevelFilter.all), hasLength(1));
      expect(filterLogs(odd, LogLevelFilter.info), isEmpty);
    });
  });

  test('the chips are labelled ALL, INFO, WARN and ERROR', () {
    expect([for (final f in LogLevelFilter.values) f.label], [
      'ALL',
      'INFO',
      'WARN',
      'ERROR',
    ]);
  });

  group('logSeverityOf', () {
    test('picks the color class of a line', () {
      expect(logSeverityOf('error'), LogSeverity.error);
      expect(logSeverityOf('warning'), LogSeverity.warn);
      expect(logSeverityOf('warn'), LogSeverity.warn);
      expect(logSeverityOf('debug'), LogSeverity.debug);
      expect(logSeverityOf('info'), LogSeverity.info);
    });

    test('an unknown level reads as plain info', () {
      expect(logSeverityOf('trace'), LogSeverity.info);
    });
  });

  test('a level is written in caps, and a warning is WARN', () {
    expect(logLevelLabel('info'), 'INFO');
    expect(logLevelLabel('warning'), 'WARN');
    expect(logLevelLabel('error'), 'ERROR');
    expect(logLevelLabel('debug'), 'DEBUG');
  });

  test('the time is hours, minutes and seconds of the device', () {
    expect(logTimeOf(DateTime(2026, 10, 27, 0, 11, 58).millisecondsSinceEpoch), '00:11:58');
    expect(logTimeOf(DateTime(2026, 10, 27, 13, 5, 9).millisecondsSinceEpoch), '13:05:09');
  });

  group('logsAsText', () {
    test('writes one line per log: time, level, message, source', () {
      expect(
        logsAsText([
          _log('info', 'started'),
          _log('warning', 'dns timeout', source: 'tun2socks'),
        ]),
        '00:11:58 [INFO] started · xray\n'
        '00:11:58 [WARN] dns timeout · tun2socks',
      );
    });

    test('is empty for no logs', () {
      expect(logsAsText(const []), '');
    });
  });

  group('logsStatusLine', () {
    test('follows the tunnel state and counts the lines', () {
      expect(
        logsStatusLine(lines: 14, tunnelUp: true, following: true),
        'FOLLOWING · 14 LINES · TUNNEL UP',
      );
      expect(
        logsStatusLine(lines: 14, tunnelUp: false, following: true),
        'FOLLOWING · 14 LINES · TUNNEL DOWN',
      );
    });

    test('says "line" for exactly one', () {
      expect(
        logsStatusLine(lines: 1, tunnelUp: true, following: true),
        'FOLLOWING · 1 LINE · TUNNEL UP',
      );
    });

    test('says PAUSED once the user has scrolled up', () {
      expect(
        logsStatusLine(lines: 14, tunnelUp: true, following: false),
        'PAUSED · 14 LINES · TUNNEL UP',
      );
    });
  });

  group('logsEmptyText', () {
    test('before any log exists it explains where logs come from', () {
      expect(
        logsEmptyText(total: 0, filter: LogLevelFilter.all),
        'Logs appear while the tunnel runs',
      );
      expect(
        logsEmptyText(total: 0, filter: LogLevelFilter.error),
        'Logs appear while the tunnel runs',
      );
    });

    test('with logs hidden by the filter it says so', () {
      expect(
        logsEmptyText(total: 20, filter: LogLevelFilter.error),
        'No ERROR lines',
      );
    });
  });

  group('logsCopyToast', () {
    test('confirms the copy and counts the lines', () {
      expect(
        logsCopyToast(14),
        const ToastSpec('Logs copied', subtitle: '14 LINES · PLAIN TEXT'),
      );
      expect(
        logsCopyToast(1),
        const ToastSpec('Logs copied', subtitle: '1 LINE · PLAIN TEXT'),
      );
    });

    test('with nothing to copy it says that instead', () {
      expect(
        logsCopyToast(0),
        const ToastSpec(
          'Nothing to copy',
          subtitle: 'NO LOG LINES YET',
          kind: ToastKind.info,
        ),
      );
    });
  });

  test('the tunnel is up only when connected', () {
    const server = VpnServer(
      id: 'a',
      subscriptionId: 's',
      countryCode: 'NL',
      title: 'A',
      configJson: '{}',
    );

    expect(
      isTunnelUp(VpnState.connected(server, connectedAt: DateTime(2026))),
      isTrue,
    );
    expect(isTunnelUp(const VpnState.connecting()), isFalse);
    expect(isTunnelUp(const VpnState.disconnected()), isFalse);
    expect(isTunnelUp(const VpnState.error('x')), isFalse);
  });
}
