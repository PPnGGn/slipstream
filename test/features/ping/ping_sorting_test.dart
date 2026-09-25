import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/ping/presentation/ping_entry.dart';
import 'package:slipstream/features/ping/presentation/ui/ping_sorting.dart';

VpnServer _server(String id, String title) => VpnServer(
  id: id,
  subscriptionId: 'sub',
  countryCode: 'US',
  title: title,
  configJson: '{}',
);

void main() {
  test('measured servers sort by latency, ties broken by title', () {
    final fast = _server('fast', 'Fast');
    final slow = _server('slow', 'Slow');
    final tieB = _server('tieB', 'B');
    final tieA = _server('tieA', 'A');

    final result = sortServersByPing([slow, tieB, fast, tieA], {
      'fast': const PingEntry(status: PingRunStatus.measured, latencyMs: 20),
      'slow': const PingEntry(status: PingRunStatus.measured, latencyMs: 200),
      'tieA': const PingEntry(status: PingRunStatus.measured, latencyMs: 50),
      'tieB': const PingEntry(status: PingRunStatus.measured, latencyMs: 50),
    });

    expect(result.map((s) => s.id), ['fast', 'tieA', 'tieB', 'slow']);
  });

  test(
    'untested/queued/measuring/unsupported keep original order, dead goes last',
    () {
      final measured = _server('measured', 'Measured');
      final untested = _server('untested', 'Untested');
      final queued = _server('queued', 'Queued');
      final unsupported = _server('unsupported', 'Unsupported');
      final dead = _server('dead', 'Dead');

      final result = sortServersByPing(
        [dead, untested, measured, unsupported, queued],
        {
          'measured': const PingEntry(
            status: PingRunStatus.measured,
            latencyMs: 30,
          ),
          'dead': const PingEntry(status: PingRunStatus.dead),
          'queued': const PingEntry.queued(),
          'unsupported': const PingEntry.unsupported(),
        },
      );

      expect(result.map((s) => s.id), [
        'measured',
        'untested',
        'unsupported',
        'queued',
        'dead',
      ]);
    },
  );
}
