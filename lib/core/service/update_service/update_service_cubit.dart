import 'dart:async';
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/app_release/app_release.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/features/update/data/update_check.dart';
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

  static const _progressThrottle = Duration(milliseconds: 200);

  final UpdateRepository _repository;
  final Talker _talker;
  StreamSubscription<int>? _downloadSubscription;
  DateTime? _lastProgressEmit;

  Future<void> check({bool userInitiated = false}) async {
    if (state case _Checking() || _Downloading()) return;

    emit(const UpdateState.checking());

    final result = await _repository.checkAndResolveCache();
    if (isClosed) return;

    switch (result) {
      case Success(data: UpdateCheckUpToDate()):
        emit(const UpdateState.upToDate());
      case Success(data: UpdateCheckReady(:final release, :final filePath)):
        emit(UpdateState.readyToInstall(release, filePath));
      case Success(
        data: UpdateCheckNeedsDownload(
          :final release,
          :final filePath,
          :final existingBytes,
        ),
      ):
        await _startDownload(release, filePath, existingBytes);
      case Failure(:final message):
        emit(
          userInitiated ? UpdateState.error(message) : const UpdateState.idle(),
        );
    }
  }

  Future<void> _startDownload(
    AppRelease release,
    String filePath,
    int existingBytes,
  ) async {
    await _downloadSubscription?.cancel();
    _lastProgressEmit = null;
    emit(UpdateState.downloading(release, receivedBytes: existingBytes));

    _downloadSubscription = _repository
        .downloadApk(release, toPath: filePath, existingBytes: existingBytes)
        .listen(
          (received) => _emitProgress(release, received),
          onDone: () {
            if (isClosed) return;
            final file = File(filePath);
            if (file.existsSync() && file.lengthSync() == release.sizeBytes) {
              emit(UpdateState.readyToInstall(release, filePath));
            } else {
              _talker.error('Updater: download size mismatch for $filePath');
              emit(const UpdateState.idle());
            }
          },
          onError: (Object e, StackTrace st) {
            _talker.handle(e, st, 'Updater: download failed');
            if (!isClosed) emit(const UpdateState.idle());
          },
          cancelOnError: true,
        );
  }

  void _emitProgress(AppRelease release, int received) {
    if (isClosed) return;
    final now = DateTime.now();
    if (_lastProgressEmit != null &&
        now.difference(_lastProgressEmit!) < _progressThrottle) {
      return;
    }
    _lastProgressEmit = now;
    emit(UpdateState.downloading(release, receivedBytes: received));
  }

  Future<void> cancelDownload() async {
    await _downloadSubscription?.cancel();
    _downloadSubscription = null;
    if (!isClosed) emit(const UpdateState.idle());
  }

  Future<void> install() async {
    final ready = state.whenOrNull(
      readyToInstall: (release, filePath) => (release, filePath),
    );
    if (ready == null) return;
    final (release, filePath) = ready;

    final result = await _repository.install(filePath);
    if (isClosed) return;
    switch (result) {
      case Success(data: InstallOutcome.launched):
        break;
      case Success(data: InstallOutcome.signatureConflict):
        emit(UpdateState.signatureConflict(release, filePath));
      case Failure(:final message):
        emit(UpdateState.error(message));
    }
  }

  Future<String?> exportApk() {
    final conflict = state.whenOrNull(
      signatureConflict: (release, filePath) => (release, filePath),
    );
    if (conflict == null) return Future.value(null);
    return _repository.exportApk(conflict.$1, conflict.$2);
  }

  Future<void> uninstallForReinstall() => _repository.uninstallForReinstall();

  void dismiss() => emit(const UpdateState.idle());

  @override
  Future<void> close() {
    _downloadSubscription?.cancel();
    return super.close();
  }
}
