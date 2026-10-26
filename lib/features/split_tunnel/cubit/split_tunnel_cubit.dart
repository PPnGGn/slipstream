import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_mode.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_settings.dart';
import 'package:slipstream/features/split_tunnel/data/split_tunnel_store.dart';

@LazySingleton()
class SplitTunnelCubit extends Cubit<SplitTunnelSettings> {
  SplitTunnelCubit({required SplitTunnelStore store})
    : _store = store,
      super(store.load());

  final SplitTunnelStore _store;

  Future<void> setEnabled({required bool enabled}) =>
      _apply(state.copyWith(enabled: enabled));

  Future<void> setMode(SplitTunnelMode mode) =>
      _apply(state.copyWith(mode: mode));

  Future<void> setAppSelected(String package, {required bool selected}) {
    final packages = {...state.packages};
    selected ? packages.add(package) : packages.remove(package);
    return _apply(state.copyWith(packages: packages));
  }

  Future<void> setIncludeSystem({required bool include}) =>
      _apply(state.copyWith(includeSystem: include));

  Future<void> _apply(SplitTunnelSettings next) async {
    if (next == state) return;
    emit(next);
    await _store.save(next);
  }
}
