import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';
import 'package:slipstream/features/vpn/data/vpn_repository.dart';

/// Budget xray-core's memory footprint is judged against.
///
/// iOS: the real jetsam kill threshold for a Network Extension (~50 MB) —
/// this is exactly what the feature exists to watch.
/// Android: there is no hard ceiling; `memoryBytes` there is
/// `runtime.MemStats.Sys` for xray-core/tun2socks alone (see
/// `V2RayVpnService.sampleMemoryBytes`), not the app process's RSS. 200 MB
/// is a rough reference point for the ok/warn/danger split — comfortably
/// above the ~34 MB the full ad-block geosite list costs on its own (see
/// `AdBlockMode.full`) plus headroom for connection buffers under load —
/// not a measured ceiling, and wants calibrating against a real device.
int get memoryBudgetBytes => Platform.isIOS ? 50 * 1024 * 1024 : 200 * 1024 * 1024;

const _warnAtFraction = 0.60;
const _dangerAtFraction = 0.85;

/// Falling back to a calmer zone requires dropping 3 points below its own
/// threshold first, so the dot doesn't flip once a second when the reading
/// sits right on a boundary.
const _hysteresis = 0.03;

enum MemoryHealth { ok, warn, danger }

class MemoryUsage {
  const MemoryUsage({this.bytes, this.health = MemoryHealth.ok});

  /// Last sampled reading, or null before the first sample / while
  /// disconnected.
  final int? bytes;
  final MemoryHealth health;
}

/// Pure zone function, kept top-level so it's testable without a cubit or a
/// stream: given the current fraction of [memoryBudgetBytes] and the zone we
/// were in a second ago, returns the zone we're in now.
MemoryHealth computeMemoryHealth(double fraction, MemoryHealth previous) {
  switch (previous) {
    case MemoryHealth.danger:
      if (fraction >= _dangerAtFraction - _hysteresis) return MemoryHealth.danger;
      return fraction >= _warnAtFraction ? MemoryHealth.warn : MemoryHealth.ok;
    case MemoryHealth.warn:
      if (fraction >= _dangerAtFraction) return MemoryHealth.danger;
      return fraction >= _warnAtFraction - _hysteresis
          ? MemoryHealth.warn
          : MemoryHealth.ok;
    case MemoryHealth.ok:
      if (fraction >= _dangerAtFraction) return MemoryHealth.danger;
      return fraction >= _warnAtFraction ? MemoryHealth.warn : MemoryHealth.ok;
  }
}

/// Tracks xray-core's memory footprint for the home screen's chip. Rides the
/// existing 1 Hz traffic tick instead of polling on its own — no new timer,
/// no extra IPC round-trip (the iOS side of that tick is already
/// budget-constrained).
@lazySingleton
class MemoryUsageCubit extends Cubit<MemoryUsage> {
  MemoryUsageCubit({required VpnRepository repository})
    : _repository = repository,
      super(const MemoryUsage()) {
    _trafficSubscription = _repository.traffic.listen(_onTraffic);
    _statusSubscription = _repository.status.listen(_onStatus);
  }

  final VpnRepository _repository;
  late final StreamSubscription<VpnTrafficMessage> _trafficSubscription;
  late final StreamSubscription<VpnStatusMessage> _statusSubscription;

  void _onStatus(VpnStatusMessage message) {
    // The native traffic tick only runs while connected, so a stale reading
    // would otherwise linger on screen through the next disconnect.
    if (message.status != VpnStatus.connected) emit(const MemoryUsage());
  }

  void _onTraffic(VpnTrafficMessage message) {
    final bytes = message.memoryBytes;
    if (bytes == null) return;
    final fraction = bytes / memoryBudgetBytes;
    emit(MemoryUsage(bytes: bytes, health: computeMemoryHealth(fraction, state.health)));
  }

  @override
  Future<void> close() {
    _trafficSubscription.cancel();
    _statusSubscription.cancel();
    return super.close();
  }
}
