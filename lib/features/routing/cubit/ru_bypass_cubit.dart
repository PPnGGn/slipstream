import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/routing/data/ru_bypass_mode.dart';
import 'package:slipstream/features/routing/data/ru_bypass_store.dart';

/// Holds the current [RuBypassMode]. Read at connect time by
/// [RoutingPolicyGate]; a change takes effect on the next connection.
@LazySingleton()
class RuBypassCubit extends Cubit<RuBypassMode> {
  RuBypassCubit({required RuBypassStore store})
    : _store = store,
      super(store.load());

  final RuBypassStore _store;

  bool get bypassRu => state == RuBypassMode.bypassRu;

  Future<void> setMode(RuBypassMode mode) async {
    if (mode == state) return;
    emit(mode);
    await _store.save(mode);
  }

  Future<void> setBypassRu({required bool enabled}) =>
      setMode(enabled ? RuBypassMode.bypassRu : RuBypassMode.off);
}
