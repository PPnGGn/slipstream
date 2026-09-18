import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';
import 'package:slipstream/features/vpn/data/vpn_repository.dart';

/// Memory budget xray-core's footprint is judged against.
///
/// iOS: the actual jetsam kill threshold for a Network Extension (~50 MB) —
/// this feature exists to watch that number.
/// Android: no hard ceiling. `memoryBytes` there is Go's `MemStats.Sys` for
/// xray-core/tun2socks (see `V2RayVpnService.sampleMemoryBytes`), not app
/// RSS. 200 MB is just a rough reference point, comfortably above the
/// ~34 MB the full ad-block list costs (`AdBlockMode.full`) — not measured,
/// needs calibrating on a real device.
int get memoryBudgetBytes => Platform.isIOS ? 50 * 1024 * 1024 : 200 * 1024 * 1024;

const _warnAtFraction = 0.60;
const _dangerAtFraction = 0.85;
const _hysteresis = 0.03;

enum MemoryHealth { ok, warn, danger }

class MemoryUsage {
  const MemoryUsage({this.bytes, this.health = MemoryHealth.ok});
  final int? bytes;
  final MemoryHealth health;
}

/// Top-level so it's testable without a cubit or a stream. Takes the
/// current fraction of [memoryBudgetBytes] and last second's zone, returns
/// the new one.
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

/// Tracks xray-core's memory footprint for the home screen chip. Piggybacks
/// on the existing 1 Hz traffic tick instead of polling on its own — no new
/// timer, no extra IPC (iOS's tick is already budget-constrained).
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
    // Traffic tick only runs while connected — clear it so a stale reading
    // doesn't linger past disconnect.
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
