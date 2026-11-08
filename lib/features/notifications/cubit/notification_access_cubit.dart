import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:slipstream/features/native_prefs/data/native_prefs_sink.dart';

/// State: whether Android lets the app show notifications at all (the
/// permission on Android 13+, or the app's switch in the system settings).
/// Starts as "allowed" so the page does not flash a warning before the first
/// answer; [refresh] reads the real one, and is called whenever the page comes
/// back to the screen (the user may have just changed it in the settings).
@LazySingleton()
class NotificationAccessCubit extends Cubit<bool> {
  NotificationAccessCubit(this._access) : super(true);

  final NativePrefsSink _access;

  Future<void> refresh() async {
    try {
      final allowed = await _access.notificationsAllowed();
      if (!isClosed) emit(allowed);
    } on Object {
      // No answer: keep what we knew.
    }
  }

  Future<void> openSettings() => _access.openNotificationSettings();
}
