import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:slipstream/features/ping/data/ping_settings_store.dart';
import 'package:slipstream/features/ping/presentation/ping_cubit.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';

/// Fires the "app start" trigger: once subscriptions are loaded, ping
/// all servers (spec trigger table), unless the user disabled it.
///
/// Runs at most once per app launch — later subscription edits are
/// covered by the manual triggers, not by this one.
@lazySingleton
class PingAutoRunner {
  PingAutoRunner(this._ping, this._settings, this._subscriptions);

  final PingCubit _ping;
  final PingSettingsStore _settings;
  final SubscriptionsCubit _subscriptions;

  StreamSubscription<SubscriptionsState>? _subscription;
  var _done = false;

  void init() {
    if (_done) return;

    void maybeRun(SubscriptionsState state) {
      if (_done || state.subscriptions.isEmpty) return;
      _done = true;
      _subscription?.cancel();
      if (!_settings.loadPingOnAppStart()) return;
      final servers = [
        for (final stored in state.subscriptions) ...stored.servers,
      ];
      unawaited(_ping.runForServers(servers));
    }

    maybeRun(_subscriptions.state);
    if (_done || _subscriptions.isClosed) return;
    _subscription = _subscriptions.stream.listen(maybeRun);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
