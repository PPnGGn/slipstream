import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/subscriptions/cubit/subscription_auto_updater.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/auto_update_interval.dart';
import 'package:slipstream/features/subscriptions/data/auto_update/subscription_update_settings_store.dart';

/// The auto-update setting as the UI sees it: the settings page changes it,
/// the subscription list shows the interval it implies.
@lazySingleton
class SubscriptionAutoUpdateCubit extends Cubit<AutoUpdateInterval> {
  SubscriptionAutoUpdateCubit(this._store, this._updater)
    : super(_store.loadInterval());

  final SubscriptionUpdateSettingsStore _store;
  final SubscriptionAutoUpdater _updater;

  Future<void> select(AutoUpdateInterval interval) async {
    if (interval == state) return;
    await _store.saveInterval(interval);
    emit(interval);
    _updater.reschedule();
  }
}
