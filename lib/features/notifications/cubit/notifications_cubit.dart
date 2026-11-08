import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/notifications/data/notification_prefs.dart';
import 'package:slipstream/features/notifications/data/notifications_store.dart';

/// State: which alerts are on. NativePrefsRunner passes every change on to the
/// VPN service (Kotlin), which decides on the spot whether to show an alert.
@LazySingleton()
class NotificationsCubit extends Cubit<NotificationPrefs> {
  NotificationsCubit({required NotificationsStore store})
    : _store = store,
      super(store.load());

  final NotificationsStore _store;

  Future<void> setTrafficBlocked({required bool enabled}) =>
      _set(state.copyWith(trafficBlocked: enabled));

  Future<void> setStartFailed({required bool enabled}) =>
      _set(state.copyWith(startFailed: enabled));

  Future<void> _set(NotificationPrefs next) async {
    if (next == state) return;
    emit(next);
    await _store.save(next);
  }
}
