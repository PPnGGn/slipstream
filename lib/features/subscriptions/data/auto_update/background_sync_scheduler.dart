import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/sync_api.g.dart';

/// Turns the OS-level periodic job on or off. That job refreshes due
/// subscriptions while the app's UI is not running; while it is, the
/// in-app timer does the work and the job returns at once.
abstract interface class BackgroundSyncScheduler {
  Future<void> setEnabled(bool enabled);
}

@LazySingleton(as: BackgroundSyncScheduler)
class PlatformBackgroundSyncScheduler implements BackgroundSyncScheduler {
  PlatformBackgroundSyncScheduler(this._talker);

  /// How often the job wakes up to check. Provider intervals are whole
  /// hours, and a subscription counts as due a few minutes early, so an
  /// hourly check lands within the hour of each due time.
  static const checkIntervalMinutes = 60;

  final Talker _talker;
  final _api = SubscriptionSyncScheduler();

  /// Android only: iOS would need a background-mode capability, which this
  /// build must not add.
  @override
  Future<void> setEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      if (enabled) {
        await _api.schedule(checkIntervalMinutes);
      } else {
        await _api.cancel();
      }
      _talker.debug('Sync: background job ${enabled ? 'on' : 'off'}');
    } catch (e) {
      _talker.warning('Sync: could not switch the background job: $e');
    }
  }
}
