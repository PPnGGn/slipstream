import 'dart:async';

import 'package:slipstream/core/models/vpn_server/vpn_server.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/launch_sync/data/launch_sync_decision.dart';
import 'package:slipstream/features/vpn/data/vpn_api.g.dart';

/// Keeps the saved launch in step with the app's settings.
///
/// The tile starts the VPN with no app around, from the launch the service
/// saved at the last start from the app. Without this, whatever the user
/// changed since (a rule, a switch, the selected server) reached the tile only
/// after the next connect from the app. Every change makes a pass: build the
/// message the app would send now, and save it, but only while nothing runs
/// (see [launchServerToSave]).
///
/// Everything it touches is handed in, so the timing and the decisions can be
/// tested without the cubits and the native side.
class LaunchSync {
  LaunchSync({
    required Stream<void> changes,
    required VpnState Function() vpnState,
    required VpnServer? Function() selectedServer,
    required Future<VpnConfigMessage> Function(VpnServer server) build,
    required Future<void> Function(VpnConfigMessage message) save,
    this.debounce = const Duration(milliseconds: 400),
    void Function(Object error, StackTrace stackTrace)? onError,
  }) : _changes = changes,
       _vpnState = vpnState,
       _selectedServer = selectedServer,
       _build = build,
       _save = save,
       _onError = onError;

  /// Changes come in bursts (a switch, then a rule, a geo download reporting
  /// progress): one pass after they settle is enough.
  final Duration debounce;

  final Stream<void> _changes;
  final VpnState Function() _vpnState;
  final VpnServer? Function() _selectedServer;
  final Future<VpnConfigMessage> Function(VpnServer server) _build;
  final Future<void> Function(VpnConfigMessage message) _save;
  final void Function(Object error, StackTrace stackTrace)? _onError;

  StreamSubscription<void>? _subscription;
  Timer? _timer;
  var _disposed = false;

  /// Starts listening for changes. Does nothing by itself until one comes; call
  /// [syncNow] for a first pass.
  void start() {
    if (_disposed) return;
    _subscription ??= _changes.listen((_) => _schedule());
  }

  void _schedule() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(syncNow()));
  }

  /// One pass, now. Never throws: a failed save only costs the tile an
  /// up-to-date launch, and the next change tries again.
  Future<void> syncNow() async {
    final server = launchServerToSave(
      vpnState: _vpnState(),
      selectedServer: _selectedServer(),
    );
    if (server == null) return;
    try {
      final message = await _build(server);
      // The world moves while the config is built: a session may have started
      // (and written its own launch), or another server been selected. Decide
      // again; a stale message is dropped, and whatever moved the world
      // schedules its own pass.
      final stillServer = launchServerToSave(
        vpnState: _vpnState(),
        selectedServer: _selectedServer(),
      );
      if (stillServer != server) return;
      await _save(message);
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}
