import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/models/result.dart';
import 'package:slipstream/features/geo/data/geo_catalog.dart';
import 'package:slipstream/features/geo/data/geo_release.dart';
import 'package:slipstream/features/geo/data/geo_repository.dart';

part 'geo_state.dart';
part 'geo_cubit.freezed.dart';

enum GeoUpdateOutcome { updated, upToDate, failed }

@lazySingleton
class GeoCubit extends Cubit<GeoState> {
  GeoCubit({required GeoRepository repository, required Talker talker})
    : _repository = repository,
      _talker = talker,
      super(const GeoState.absent()) {
    _init();
  }

  static const _progressThrottle = Duration(milliseconds: 150);

  final GeoRepository _repository;
  final Talker _talker;
  StreamSubscription<GeoDownloadProgress>? _download;
  DateTime? _lastProgressEmit;

  Future<void> _init() async {
    final installed = await _repository.installed();
    if (isClosed) return;
    switch (installed) {
      case GeoInstalledOk(:final meta):
        emit(
          GeoState.ready(
            catalog: meta.catalog,
            tag: meta.tag,
            updatedAt: meta.updatedAt,
          ),
        );
      case GeoNotInstalled():
        emit(const GeoState.absent());
    }
  }

  /// Checks the latest release and installs it only if its tag differs from
  /// what's on disk. One round-trip (unlike a separate check + download).
  ///
  /// The tag is a sound "is there an update" signal here: the build workflow
  /// publishes a new release — hence a new tag — *only* when the trimmed
  /// bytes actually changed (its skip-if-unchanged gate compares
  /// sha256sums.txt), so tag-changed ⟺ content-changed.
  Future<GeoUpdateOutcome> updateIfNewer() async {
    if (state is GeoDownloading || state is GeoChecking) {
      return GeoUpdateOutcome.upToDate;
    }
    final before = state;
    final installedTag = switch (before) {
      GeoReady(:final tag) => tag,
      GeoUpdateAvailable(:final tag) => tag,
      _ => null,
    };

    emit(const GeoState.checking());
    final result = await _repository.latestRelease();
    if (isClosed) return GeoUpdateOutcome.failed;

    switch (result) {
      case Failure(:final message):
        emit(GeoState.failed(message));
        return GeoUpdateOutcome.failed;
      case Success(:final data):
        if (installedTag != null && installedTag == data.tag) {
          emit(before); // already current
          return GeoUpdateOutcome.upToDate;
        }
        await _download_(data);
        return state is GeoFailed
            ? GeoUpdateOutcome.failed
            : GeoUpdateOutcome.updated;
    }
  }

  /// Fetches the latest release and installs it, regardless of current state.
  /// Pass [known] to skip the release lookup (the caller already has one).
  Future<void> downloadLatest([GeoRelease? known]) async {
    if (state is GeoDownloading) return;
    if (known != null) {
      await _download_(known);
      return;
    }
    final result = await _repository.latestRelease();
    if (isClosed) return;
    switch (result) {
      case Failure(:final message):
        emit(GeoState.failed(message));
      case Success(:final data):
        await _download_(data);
    }
  }

  /// Drives one [GeoRepository.download] to completion, emitting progress and
  /// the terminal `ready`/`failed` state. The returned future completes only
  /// when the download is actually done — callers can `await` it and then
  /// trust `state` (the earlier `.listen()` returned immediately, so
  /// `updateNow` reported success while bytes were still in flight).
  Future<void> _download_(GeoRelease release) async {
    await _download?.cancel();
    _lastProgressEmit = null;
    emit(
      GeoState.downloading(fraction: 0, received: 0, total: release.totalBytes),
    );

    final done = Completer<void>();
    _download = _repository
        .download(release)
        .listen(
          (p) {
            if (isClosed) return;
            if (p.done && p.meta != null) {
              emit(
                GeoState.ready(
                  catalog: p.meta!.catalog,
                  tag: p.meta!.tag,
                  updatedAt: p.meta!.updatedAt,
                ),
              );
              return;
            }
            final now = DateTime.now();
            if (_lastProgressEmit != null &&
                now.difference(_lastProgressEmit!) < _progressThrottle) {
              return;
            }
            _lastProgressEmit = now;
            emit(
              GeoState.downloading(
                fraction: p.fraction,
                received: p.received,
                total: p.total,
              ),
            );
          },
          onError: (Object e, StackTrace st) {
            _talker.handle(e, st, 'Geo: download failed');
            if (!isClosed) emit(GeoState.failed('$e'));
            if (!done.isCompleted) done.complete();
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
          cancelOnError: true,
        );

    return done.future;
  }

  @override
  Future<void> close() {
    _download?.cancel();
    return super.close();
  }
}
