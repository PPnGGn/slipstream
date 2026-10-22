import 'package:pigeon/pigeon.dart';

/// Main engine -> native: the periodic WorkManager job that refreshes
/// subscriptions while the app's UI is not running (Android only).
@HostApi()
abstract class SubscriptionSyncScheduler {
  /// Starts (or updates) the periodic job. Keeps a single job however often
  /// it is called.
  void schedule(int intervalMinutes);

  void cancel();
}

/// Headless engine -> native: registered only on the engine the background
/// job starts, so the job knows when the Dart side is done.
@HostApi()
abstract class BackgroundTaskHost {
  void finished(bool success);
}
