import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/ping/data/real_delay_client.dart';
import 'package:slipstream/features/ping/presentation/real_delay_entry.dart';
import 'package:slipstream/features/subscriptions/data/server_problem.dart';

/// The result of every check of this run of the app, by server id.
class RealDelayState {
  const RealDelayState([this.entries = const {}]);

  final Map<String, RealDelayEntry> entries;

  RealDelayEntry of(String serverId) =>
      entries[serverId] ?? const RealDelayEntry.notTested();

  /// A check is running. Checks go one at a time: each starts an xray in the
  /// core and holds the radio for seconds.
  bool get busy =>
      entries.values.any((e) => e.status == RealDelayStatus.measuring);
}

/// Runs the "Real delay" check on a tap. A check never starts by itself, and
/// there is no queue: a tap while another check runs is ignored.
///
/// The results live as long as the app does, so a sheet that is opened again
/// shows the number of the last check. The server list does not read them.
@lazySingleton
class RealDelayCubit extends Cubit<RealDelayState> {
  RealDelayCubit(this._client) : super(const RealDelayState());

  final RealDelayClient _client;

  Future<void> measure(VpnServer server) async {
    // A server that cannot work is told by its config, no request needed.
    if (state.busy || serverProblem(server) != null) return;

    _set(server.id, const RealDelayEntry.measuring());
    RealDelayEntry entry;
    try {
      final outcome = await _client.measure(server);
      entry = outcome.latencyMs != null
          ? RealDelayEntry.measured(outcome.latencyMs!)
          : RealDelayEntry.failed(outcome.failure!);
    } catch (_) {
      entry = const RealDelayEntry.failed(RealDelayFailure.other);
    }
    if (isClosed) return;
    _set(server.id, entry);
  }

  void _set(String serverId, RealDelayEntry entry) =>
      emit(RealDelayState({...state.entries, serverId: entry}));
}
