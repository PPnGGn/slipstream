import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/diagnostics/data/memory_monitor_mode.dart';
import 'package:slipstream/features/diagnostics/data/memory_monitor_store.dart';

@LazySingleton()
class MemoryMonitorCubit extends Cubit<MemoryMonitorMode> {
  MemoryMonitorCubit({required MemoryMonitorStore store})
    : _store = store,
      super(store.load());

  final MemoryMonitorStore _store;

  Future<void> setMode(MemoryMonitorMode mode) async {
    if (mode == state) return;
    emit(mode);
    await _store.save(mode);
  }

  Future<void> setEnabled({required bool enabled}) =>
      setMode(enabled ? MemoryMonitorMode.on : MemoryMonitorMode.off);
}
