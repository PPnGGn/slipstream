package com.slipstream.ping

import android.os.Handler
import android.os.Looper
import com.slipstream.android.Android

// Real delay: one request through one server, made by the Go core (see
// MeasureDelay there). Thin on purpose: this class only moves the call off the
// main thread and the answer back onto it. Where the three steps run is passed
// in, so a test can run them in one thread and check the order.
class RealDelayApiImpl(
        private val measure: (configJson: String, assetDir: String, url: String, timeoutMs: Int) -> Long =
                { configJson, assetDir, url, timeoutMs ->
                    Android.measureDelay(configJson, assetDir, url, timeoutMs.toLong())
                },
        private val runInBackground: (() -> Unit) -> Unit = { work -> Thread(work, "real-delay").start() },
        private val onMain: (() -> Unit) -> Unit = { work ->
            Handler(Looper.getMainLooper()).post(work)
        },
) : RealDelayApi {

    // The core blocks up to timeoutMs, and Pigeon wants its reply on the main
    // thread. A failure is an answer, not an exception: "this server does not
    // work" is what the user came to find out. The config carries credentials,
    // so neither it nor the core's text is logged here.
    override fun measure(request: RealDelayRequest, callback: (Result<RealDelayResult>) -> Unit) {
        runInBackground {
            val result =
                    try {
                        val ms =
                                measure(
                                        request.configJson,
                                        request.geoAssetDir,
                                        request.url,
                                        request.timeoutMs.toInt(),
                                )
                        RealDelayResult(latencyMs = ms)
                    } catch (e: Exception) {
                        RealDelayResult(error = e.message?.takeIf { it.isNotEmpty() } ?: "measure failed")
                    }
            onMain { callback(Result.success(result)) }
        }
    }
}
