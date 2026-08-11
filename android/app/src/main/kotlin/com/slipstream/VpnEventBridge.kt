package com.slipstream

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.slipstream.android.Handler as CoreLogHandler

object VpnEventBridge : CoreLogHandler {

    @Volatile var receiver: VpnEventReceiver? = null

    @Volatile private var lastStatus: VpnStatus = VpnStatus.DISCONNECTED

    @Volatile private var lastError: String? = null

    @Volatile private var lastConnectedAtEpochMs: Long? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    fun currentStatus(): VpnStatusMessage =
            VpnStatusMessage(lastStatus, lastError, lastConnectedAtEpochMs)

    fun notifyStatus(status: VpnStatus, error: String? = null, connectedAtEpochMs: Long? = null) {
        lastStatus = status
        lastError = error
        lastConnectedAtEpochMs =
                when (status) {
                    VpnStatus.CONNECTED -> connectedAtEpochMs
                                    ?: lastConnectedAtEpochMs ?: System.currentTimeMillis()
                    VpnStatus.DISCONNECTED, VpnStatus.ERROR -> null
                    else -> lastConnectedAtEpochMs
                }

        val receiver = this.receiver
        if (receiver == null) {
            Log.w("VPN_BRIDGE", "No Flutter engine attached, status update cached: $status")
            return
        }
        val message = VpnStatusMessage(status, error, lastConnectedAtEpochMs)
        mainHandler.post {
            receiver.onStatusChanged(message) { result ->
                result.onFailure { e ->
                    Log.e("VPN_BRIDGE", "Failed to deliver status to Dart: ${e.message}")
                }
            }
        }
    }

    fun notifyTraffic(uplinkBytes: Long, downlinkBytes: Long) {
        val receiver = this.receiver ?: return
        val message = VpnTrafficMessage(uplinkBytes, downlinkBytes)
        mainHandler.post {
            receiver.onTraffic(message) { result ->
                result.onFailure { e ->
                    Log.e("VPN_BRIDGE", "Failed to deliver traffic to Dart: ${e.message}")
                }
            }
        }
    }

    override fun onLog(level: String, message: String, source: String) {
        val receiver = this.receiver ?: return
        val entry = VpnLogMessage(level, message, source, System.currentTimeMillis())
        mainHandler.post {
            receiver.onLog(entry) { result ->
                result.onFailure { e ->
                    Log.e("VPN_BRIDGE", "Failed to deliver log to Dart: ${e.message}")
                }
            }
        }
    }
}
