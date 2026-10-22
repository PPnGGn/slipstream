import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/core/service/vpn_service/vpn_service_cubit.dart';
import 'package:slipstream/features/subscriptions/cubit/subscriptions_cubit.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/auto_update_interval.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/background_sync_scheduler.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/subscription_update_policy.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/subscription_update_settings_store.dart';

/// Decides *when* subscriptions refresh while the app runs:
///
///  - **Due:** one timer, set to the nearest due time and recomputed whenever
///    the list or the setting changes. Fires at once for anything overdue,
///    which covers app start.
///  - **Resume:** re-reads storage (the background job may have refreshed
///    subscriptions while the UI was away) and recomputes the timer — a long
///    timer does not count the time the device slept.
///  - **Tunnel up:** retries subscriptions whose last attempt failed, since
///    the fetcher can now fall back to the tunnel.
///
/// It also keeps the OS background job on exactly while there is something
/// to auto-update.
@lazySingleton
class SubscriptionAutoUpdater {
  SubscriptionAutoUpdater(
    this._subscriptions,
    this._settings,
    this._vpn,
    this._background,
    this._talker, {
    @ignoreParam DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SubscriptionsCubit _subscriptions;
  final SubscriptionUpdateSettingsStore _settings;
  final VpnServiceCubit _vpn;
  final BackgroundSyncScheduler _background;
  final Talker _talker;
  final DateTime Function() _now;

  StreamSubscription<SubscriptionsState>? _subscriptionsSub;
  StreamSubscription<VpnState>? _vpnSub;
  AppLifecycleListener? _lifecycle;
  Timer? _timer;
  bool? _backgroundEnabled;
  var _running = false;
  var _wasConnected = false;

  void init() {
    if (_subscriptionsSub != null) return;
    _wasConnected = _isConnected(_vpn.state);
    _subscriptionsSub = _subscriptions.stream.listen((_) => _reschedule());
    _vpnSub = _vpn.stream.listen(_onVpnState);
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_onResume()));
    _reschedule();
  }

  /// Call after the auto-update setting changed.
  void reschedule() => _reschedule();

  void _reschedule() {
    final state = _subscriptions.state;
    if (!state.isLoaded) return;
    final setting = _settings.loadInterval();
    _syncBackground(state, setting);

    _timer?.cancel();
    _timer = null;
    // A subscription refreshing right now is left out: it gets a new due
    // time when it finishes, and counting it would fire the timer at once,
    // over and over, until it does.
    final delay = delayUntilNextUpdate(
      [
        for (final s in state.subscriptions)
          if (!state.refreshingIds.contains(s.subscription.id)) s.subscription,
      ],
      setting,
      _now(),
    );
    if (delay != null) {
      _timer = Timer(delay, () => unawaited(_refreshDue()));
    }
  }

  void _syncBackground(SubscriptionsState state, AutoUpdateInterval setting) {
    final enabled =
        setting != AutoUpdateInterval.off &&
        state.subscriptions.any((s) => s.subscription.url != null);
    if (enabled == _backgroundEnabled) return;
    _backgroundEnabled = enabled;
    unawaited(_background.setEnabled(enabled));
  }

  Future<void> _refreshDue() async {
    if (_running) return;
    _running = true;
    try {
      final setting = _settings.loadInterval();
      final now = _now();
      final due = [
        for (final s in _subscriptions.state.subscriptions)
          if (isUpdateDue(s.subscription, setting, now)) s.subscription.id,
      ];
      if (due.isEmpty) return;
      _talker.info('AutoUpdate: refreshing ${due.length} subscription(s)');
      for (final id in due) {
        await _subscriptions.refreshSubscription(id);
      }
    } finally {
      _running = false;
      _reschedule();
    }
  }

  Future<void> _onResume() async {
    await _subscriptions.reloadFromStorage();
    _reschedule();
  }

  void _onVpnState(VpnState state) {
    final connected = _isConnected(state);
    final justConnected = connected && !_wasConnected;
    _wasConnected = connected;
    if (justConnected) unawaited(_retryFailed());
  }

  Future<void> _retryFailed() async {
    final setting = _settings.loadInterval();
    final failed = [
      for (final s in _subscriptions.state.subscriptions)
        if (s.subscription.lastError != null &&
            effectiveUpdateInterval(s.subscription, setting) != null)
          s.subscription.id,
    ];
    if (failed.isEmpty) return;
    _talker.info(
      'AutoUpdate: tunnel up, retrying ${failed.length} failed subscription(s)',
    );
    for (final id in failed) {
      await _subscriptions.refreshSubscription(id);
    }
  }

  static bool _isConnected(VpnState state) =>
      state.maybeWhen(connected: (_, _, _, _) => true, orElse: () => false);

  @disposeMethod
  Future<void> dispose() async {
    _timer?.cancel();
    _lifecycle?.dispose();
    await _subscriptionsSub?.cancel();
    await _vpnSub?.cancel();
  }
}
