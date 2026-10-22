package com.slipstream.sync

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.slipstream.VpnConnection
import com.slipstream.device.DeviceInfoApi
import com.slipstream.device.DeviceInfoApiImpl
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import kotlin.coroutines.resume
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull

// The periodic background job: refreshes due subscriptions while the UI is not
// running. Starts a headless Flutter engine on `subscriptionSyncMain` (lib/main.dart),
// waits for it to report back and destroys it.
//
// Always ends in success: Dart saves every failure and its own back-off decides the
// retry, so WorkManager's retry/back-off must not add runs on top.
class SubscriptionSyncWorker(context: Context, params: WorkerParameters) :
        CoroutineWorker(context, params) {

    companion object {
        private const val TAG = "SUBSCRIPTION_SYNC"
        private const val ENTRYPOINT = "subscriptionSyncMain"

        // A fetch takes up to 10 s direct plus 10 s through the tunnel, per
        // subscription; this leaves room for several and still ends well within
        // WorkManager's 10-minute limit.
        private const val RUN_TIMEOUT_MS = 3 * 60 * 1000L
    }

    override suspend fun doWork(): Result {
        if (MainEngine.attached) {
            Log.d(TAG, "UI engine is up, its own timer refreshes subscriptions")
            return Result.success()
        }
        val ok = withTimeoutOrNull(RUN_TIMEOUT_MS) { runHeadless() }
        Log.i(TAG, "Background sync done: ${ok ?: "timed out"}")
        return Result.success()
    }

    // Everything on the main thread: the Flutter loader and engine require it.
    private suspend fun runHeadless(): Boolean =
            withContext(Dispatchers.Main) {
                val context = applicationContext
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(context)
                suspendCancellableCoroutine { cont ->
                    loader.ensureInitializationCompleteAsync(
                            context,
                            null,
                            Handler(Looper.getMainLooper()),
                    ) { cont.resume(Unit) }
                }

                // Pub plugins (path_provider, shared_preferences) register on
                // their own; the app's Pigeon APIs are added by hand.
                val engine = FlutterEngine(context)
                try {
                    suspendCancellableCoroutine { cont ->
                        val messenger = engine.dartExecutor.binaryMessenger
                        DeviceInfoApi.setUp(messenger, DeviceInfoApiImpl(context))
                        VpnConnection.setUp(messenger, HeadlessVpnConnection(context))
                        BackgroundTaskHost.setUp(
                                messenger,
                                object : BackgroundTaskHost {
                                    override fun finished(success: Boolean) {
                                        if (cont.isActive) cont.resume(success)
                                    }
                                },
                        )
                        engine.dartExecutor.executeDartEntrypoint(
                                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), ENTRYPOINT),
                        )
                    }
                } finally {
                    engine.destroy()
                }
            }
}
