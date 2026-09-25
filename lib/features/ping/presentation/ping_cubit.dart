import 'dart:math' show min;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/features/ping/data/ping_settings_store.dart';
import 'package:slipstream/features/ping/data/ping_target_resolver.dart';
import 'package:slipstream/features/ping/domain/entities/ping_round_result.dart';
import 'package:slipstream/features/ping/domain/entities/ping_target.dart';
import 'package:slipstream/features/ping/domain/usecases/measure_ping_use_case.dart';
import 'package:slipstream/features/ping/presentation/ping_entry.dart';

/// Whole-screen ping state: one entry per server id, plus the display
/// settings that the badge and list sorting react to.
class PingViewState {
  const PingViewState({
    this.entries = const {},
    this.displayMode = PingDisplayMode.numbers,
    this.sortByPing = true,
    this.isRunning = false,
  });

  final Map<String, PingEntry> entries;
  final PingDisplayMode displayMode;
  final bool sortByPing;

  /// True while any round of the latest run is still in flight.
  /// The list keeps its order during a run and re-sorts when this
  /// flips to false (spec: sort once, after all rounds finish).
  final bool isRunning;

  PingViewState copyWith({
    Map<String, PingEntry>? entries,
    PingDisplayMode? displayMode,
    bool? sortByPing,
    bool? isRunning,
  }) => PingViewState(
    entries: entries ?? this.entries,
    displayMode: displayMode ?? this.displayMode,
    sortByPing: sortByPing ?? this.sortByPing,
    isRunning: isRunning ?? this.isRunning,
  );
}

/// One cubit for the whole server list screen (spec: not per-card).
/// Runs a fixed-size worker pool over all resolved targets and drops
/// results from superseded runs via a generation counter.
@lazySingleton
class PingCubit extends Cubit<PingViewState> {
  PingCubit(this._measure, this._resolver, this._settings)
    : super(
        PingViewState(
          displayMode: _settings.loadDisplayMode(),
          sortByPing: _settings.loadSortByPing(),
        ),
      );

  /// Spec: 5-10 concurrent probes; keeps 50+ servers from opening all
  /// sockets at once. Each round is now at most 3 short attempts (see
  /// MeasurePingUseCase), so a worker pool pulling from a shared queue
  /// keeps every slot busy instead of waiting for the slowest server
  /// in a fixed batch before starting the next one.
  static const maxConcurrentPings = 8;

  final MeasurePingUseCase _measure;
  final PingTargetResolver _resolver;
  final PingSettingsStore _settings;

  var _generation = 0;

  /// The single pipeline for all three triggers; callers only differ
  /// in which server list they pass (spec: one method, param = ids).
  Future<void> runForServers(List<VpnServer> servers) async {
    _generation++;
    final generation = _generation;

    final targets = <MapEntry<VpnServer, PingTarget>>[];
    for (final server in servers) {
      final target = _resolver.resolve(server);
      if (target != null) targets.add(MapEntry(server, target));
    }
    if (targets.isEmpty) return;

    emit(
      state.copyWith(
        isRunning: true,
        entries: {
          ...state.entries,
          for (final t in targets)
            t.key.id: t.value.probe == PingProbe.none
                ? const PingEntry.unsupported()
                : const PingEntry.queued(),
        },
      ),
    );

    // mKCP servers never enter the work queue: there's no probe for
    // them, so they'd just sit as "unsupported" forever if they did.
    final queue = [
      for (final t in targets)
        if (t.value.probe != PingProbe.none) t,
    ];

    // Each worker walks a disjoint stride (0, N, 2N, ...) instead of
    // pulling from a shared cursor — nothing to coordinate, so there's
    // no race to get wrong.
    final workerCount = min(maxConcurrentPings, queue.length);

    Future<void> worker(int start) async {
      var index = start;
      while (index < queue.length) {
        if (generation != _generation || isClosed) return;
        await _runRound(generation, queue[index]);
        index += workerCount;
      }
    }

    await Future.wait(List.generate(workerCount, worker));

    if (generation == _generation && !isClosed) {
      emit(state.copyWith(isRunning: false));
    }
  }

  Future<void> _runRound(
    int generation,
    MapEntry<VpnServer, PingTarget> target,
  ) async {
    final server = target.key;
    _patchEntry(generation, server.id, const PingEntry.measuring());

    final result = await _measure.measure(target.value);
    _patchEntry(
      generation,
      server.id,
      PingEntry(
        status: result.status == PingRoundStatus.unreachable
            ? PingRunStatus.dead
            : PingRunStatus.measured,
        latencyMs: result.latencyMs,
        attemptCount: result.attemptCount,
        successCount: result.successCount,
        failureReason: result.failureReason,
      ),
    );
  }

  void _patchEntry(int generation, String serverId, PingEntry entry) {
    if (generation != _generation || isClosed) return;
    emit(state.copyWith(entries: {...state.entries, serverId: entry}));
  }

  void setDisplayMode(PingDisplayMode mode) {
    _settings.saveDisplayMode(mode);
    emit(state.copyWith(displayMode: mode));
  }

  void setSortByPing(bool enabled) {
    _settings.saveSortByPing(enabled);
    emit(state.copyWith(sortByPing: enabled));
  }
}
