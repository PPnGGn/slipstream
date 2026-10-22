package com.slipstream

import android.content.Context
import android.net.ConnectivityManager
import android.os.Build
import com.slipstream.android.Android
import java.io.File

// Read-only VPN queries that need no Activity: shared by MainActivity and the
// background job's headless engine (HeadlessVpnConnection).
object VpnQueries {

    fun geoDir(context: Context): String =
            File(context.filesDir, "geo").apply { mkdirs() }.absolutePath

    // Same process as V2RayVpnService, so the Go core's session state is right here.
    // Carries the proxy password: never log the result.
    fun localProxy(): LocalProxyMessage? {
        val proxy = Android.localHTTPProxy() ?: return null
        return LocalProxyMessage(port = proxy.port, user = proxy.user, pass = proxy.pass)
    }

    // Private DNS is a global setting, so any network's LinkProperties carry it:
    // a server name is set only in strict ("hostname") mode.
    fun privateDnsStrict(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false
        val cm = context.getSystemService(ConnectivityManager::class.java) ?: return false
        val network = cm.activeNetwork ?: return false
        return cm.getLinkProperties(network)?.privateDnsServerName != null
    }
}
