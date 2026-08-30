import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/app_release/app_release.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/features/update/data/update_repository.dart';

part 'update_service_state.dart';
part 'update_service_cubit.freezed.dart';

@lazySingleton
class UpdateServiceCubit extends Cubit<UpdateState> {
  UpdateServiceCubit({
    required UpdateRepository repository,
    required Talker talker,
  }) : _repository = repository,
       _talker = talker,
       super(const UpdateState.idle());

  final UpdateRepository _repository;
  final Talker _talker;
  StreamSubscription<int>? _downloadSubscription;

  Future<void> check() async {
    emit(const UpdateState.checking());

    final result = await _repository.checkForUpdate();
    switch (result) {
      case Success(data: final release?):
        emit(UpdateState.available(release));
      case Success():
        emit(const UpdateState.upToDate());
      case Failure(:final message):
        emit(UpdateState.error(message));
    }
  }

  Future<void> download() async {
    final release = state.whenOrNull(available: (release) => release);
    if (release == null) return;

    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/slipstream-update.apk';

    emit(UpdateState.downloading(release, receivedBytes: 0));
    _downloadSubscription = _repository
        .downloadApk(release, toPath: filePath)
        .listen(
          (received) =>
              emit(UpdateState.downloading(release, receivedBytes: received)),
          onDone: () => emit(UpdateState.readyToInstall(release, filePath)),
          onError: (Object e, StackTrace st) {
            _talker.handle(e, st, 'Updater: download failed');
            emit(UpdateState.error('Download failed: $e'));
          },
        );
  }

  Future<void> cancelDownload() async {
    await _downloadSubscription?.cancel();
    _downloadSubscription = null;
    final release = state.whenOrNull(downloading: (release, _) => release);
    if (release != null) emit(UpdateState.available(release));
  }

  Future<void> install() async {
    final filePath = state.whenOrNull(
      readyToInstall: (_, filePath) => filePath,
    );
    if (filePath == null) return;

    final result = await _repository.install(filePath);
    if (result case Failure(:final message)) {
      emit(UpdateState.error(message));
    }
  }

  void dismiss() => emit(const UpdateState.idle());

  @override
  Future<void> close() {
    _downloadSubscription?.cancel();
    return super.close();
  }
}
