package com.slipstream.sync

import android.content.Context
import com.slipstream.LocalProxyMessage
import com.slipstream.VpnConfigMessage
import com.slipstream.VpnConnection
import com.slipstream.VpnEventBridge
import com.slipstream.VpnQueries
import com.slipstream.VpnResult
import com.slipstream.VpnStatusMessage
import com.slipstream.android.Android

// VpnConnection for the background job's headless engine: answers the queries
// (above all localProxy, so a subscription fetch can fall back to the tunnel
// when the VPN runs without the UI) and refuses start/stop, which need the
// Activity for the VPN permission prompt.
class HeadlessVpnConnection(private val context: Context) : VpnConnection {

    override fun start(config: VpnConfigMessage, callback: (Result<VpnResult>) -> Unit) {
        callback(Result.success(VpnResult(successful = false, error = "Not available in background")))
    }

    override fun stop(callback: (Result<VpnResult>) -> Unit) {
        callback(Result.success(VpnResult(successful = false, error = "Not available in background")))
    }

    override fun getStatus(callback: (Result<VpnStatusMessage>) -> Unit) {
        callback(Result.success(VpnEventBridge.currentStatus()))
    }

    override fun geoAssetDir(): String = VpnQueries.geoDir(context)

    override fun xrayCoreVersion(): String = Android.version()

    // Carries the proxy password: never log the result.
    override fun localProxy(): LocalProxyMessage? = VpnQueries.localProxy()

    override fun privateDnsStrict(): Boolean = VpnQueries.privateDnsStrict(context)
}
