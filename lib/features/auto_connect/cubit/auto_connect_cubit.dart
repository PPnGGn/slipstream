import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/auto_connect/data/auto_connect_store.dart';

/// State: whether the app connects by itself when it opens. Read once per
/// process by the AutoConnectRunner; the settings row writes it.
@LazySingleton()
class AutoConnectCubit extends Cubit<bool> {
  AutoConnectCubit({required AutoConnectStore store})
    : _store = store,
      super(store.load());

  final AutoConnectStore _store;

  Future<void> setEnabled({required bool enabled}) async {
    if (enabled == state) return;
    emit(enabled);
    await _store.save(enabled: enabled);
  }
}
