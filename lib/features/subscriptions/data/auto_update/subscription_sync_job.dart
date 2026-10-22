import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/subscription_update_policy.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/subscription_update_settings_store.dart';
import 'package:slipstream/features/subscriptions/data/subscription_refresher.dart';
import 'package:slipstream/features/subscriptions/data/subscription_storage/subscription_storage.dart';

/// One run of the background job: refreshes every subscription that is due
/// straight from storage. Runs in the headless engine, so it touches no
/// cubit — the UI picks the result up from disk when it comes back.
@lazySingleton
class SubscriptionSyncJob {
  SubscriptionSyncJob(
    this._storage,
    this._refresher,
    this._settings,
    this._talker, {
    @ignoreParam DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SubscriptionStorage _storage;
  final SubscriptionRefresher _refresher;
  final SubscriptionUpdateSettingsStore _settings;
  final Talker _talker;
  final DateTime Function() _now;

  /// False when any refresh failed. The failure is saved either way, so the
  /// policy's back-off decides the retry, not the OS.
  Future<bool> run() async {
    final setting = _settings.loadInterval();
    final now = _now();
    final due = [
      for (final stored in await _storage.loadAll())
        if (isUpdateDue(stored.subscription, setting, now)) stored,
    ];
    _talker.info('Sync: ${due.length} subscription(s) due');

    var ok = true;
    for (final stored in due) {
      final id = stored.subscription.id;
      final updated = await _refresher.refresh(stored);
      if (!await _storage.exists(id)) {
        _talker.debug('Sync: $id deleted mid-refresh, not saving');
        continue;
      }
      await _storage.save(updated);
      final error = updated.subscription.lastError;
      if (error != null) {
        ok = false;
        _talker.warning('Sync: $id failed -> $error');
      }
    }
    return ok;
  }
}
