import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/split_tunnel/data/installed_apps_api.g.dart';
import 'package:slipstream/features/split_tunnel/data/installed_apps_repository.dart';

part 'installed_apps_state.dart';
part 'installed_apps_cubit.freezed.dart';

@injectable
class InstalledAppsCubit extends Cubit<InstalledAppsState> {
  InstalledAppsCubit(this._repository) : super(const InstalledAppsLoading());

  final InstalledAppsRepository _repository;

  Future<void> load() async {
    emit(const InstalledAppsLoading());
    try {
      emit(InstalledAppsLoaded(await _repository.load()));
    } catch (e) {
      emit(InstalledAppsFailed(e.toString()));
    }
  }

  void setQuery(String query) {
    final current = state;
    if (current is! InstalledAppsLoaded) return;
    emit(InstalledAppsLoaded(current.apps, query: query));
  }

  Future<Uint8List?> iconFor(String packageName) =>
      _repository.icon(packageName);
}
