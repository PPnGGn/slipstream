import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/security/data/kill_switch_store.dart';

/// State: whether the kill switch is on. The value reaches the VPN service
/// with the next connect (see VpnRepository.start), not while it runs.
@LazySingleton()
class KillSwitchCubit extends Cubit<bool> {
  KillSwitchCubit({required KillSwitchStore store})
    : _store = store,
      super(store.load());

  final KillSwitchStore _store;

  Future<void> setEnabled({required bool enabled}) async {
    if (enabled == state) return;
    emit(enabled);
    await _store.save(enabled: enabled);
  }
}
