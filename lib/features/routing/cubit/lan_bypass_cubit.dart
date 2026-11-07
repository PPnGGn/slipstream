import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/routing/data/lan_bypass_store.dart';

/// State: whether the local network (private ranges, localhost) goes direct.
/// Read at connect time by RoutingPolicyGate; a change takes effect on the
/// next connection, not while the tunnel runs.
@LazySingleton()
class LanBypassCubit extends Cubit<bool> {
  LanBypassCubit({required LanBypassStore store})
    : _store = store,
      super(store.load());

  final LanBypassStore _store;

  Future<void> setEnabled({required bool enabled}) async {
    if (enabled == state) return;
    emit(enabled);
    await _store.save(enabled: enabled);
  }
}
