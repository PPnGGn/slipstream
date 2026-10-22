import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/ping/data/ping_settings_store.dart';
import 'package:slipstream/features/ping/presentation/ping_cubit.dart';
import 'package:slipstream/features/ping/presentation/ping_triggers.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';

/// Fires the automatic ping triggers:
///
///  - **App start:** once subscriptions are loaded, ping all servers (spec
///    trigger table), unless the user disabled it.
///  - **Back to the app:** the same full run, under the same setting, when
///    the last one is older than [repingOnResumeAfter].
///  - **Subscription refreshed:** ping that subscription's servers — a
///    refresh (manual, automatic or from the background job) may bring
///    servers that were never measured.
///
/// Manual runs (pull-to-refresh, the ⋯ menu) stay in the UI.
@lazySingleton
class PingAutoRunner {
  PingAutoRunner(
    this._ping,
    this._settings,
    this._subscriptions, {
    @ignoreParam DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final PingCubit _ping;
  final PingSettingsStore _settings;
  final SubscriptionsCubit _subscriptions;
  final DateTime Function() _now;

  StreamSubscription<SubscriptionsState>? _subscription;
  AppLifecycleListener? _lifecycle;
  SubscriptionsState? _previous;
  DateTime? _lastFullRunAt;
  var _startDone = false;

  void init() {
    if (_subscription != null || _subscriptions.isClosed) return;
    _onSubscriptions(_subscriptions.state);
    _subscription = _subscriptions.stream.listen(_onSubscriptions);
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  void _onSubscriptions(SubscriptionsState state) {
    final previous = _previous;
    _previous = state;

    if (!_startDone) {
      if (state.subscriptions.isEmpty) return;
      _startDone = true;
      if (_settings.loadPingOnAppStart()) _pingAll(state);
      return;
    }
    if (previous == null) return;

    for (final id in refreshedSubscriptionIds(previous, state)) {
      final stored = state.subscriptions.firstWhere(
        (s) => s.subscription.id == id,
      );
      unawaited(_ping.runForServers(stored.servers));
    }
  }

  void _onResume() {
    if (!_startDone || !_settings.loadPingOnAppStart()) return;
    if (!shouldRepingOnResume(_lastFullRunAt, _now())) return;
    _pingAll(_subscriptions.state);
  }

  void _pingAll(SubscriptionsState state) {
    _lastFullRunAt = _now();
    final servers = [
      for (final stored in state.subscriptions) ...stored.servers,
    ];
    unawaited(_ping.runForServers(servers));
  }

  Future<void> dispose() async {
    _lifecycle?.dispose();
    _lifecycle = null;
    await _subscription?.cancel();
    _subscription = null;
  }
}
