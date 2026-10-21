import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/appearance/data/home_layout.dart';
import 'package:slipstream/features/appearance/data/home_layout_store.dart';

@LazySingleton()
class HomeLayoutCubit extends Cubit<HomeLayout> {
  HomeLayoutCubit({required HomeLayoutStore store})
    : _store = store,
      super(store.load());

  final HomeLayoutStore _store;

  Future<void> setLayout(HomeLayout layout) async {
    if (layout == state) return;
    emit(layout);
    await _store.save(layout);
  }
}
