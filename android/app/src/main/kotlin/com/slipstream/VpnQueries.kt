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

    // Where the core serves the HTTP proxy for the app's own requests: a Unix
    // socket in the app's private directory, not a TCP port, because a port on
    // the loopback can be found by every other app on the phone. Keep the path
    // short, a socket path is limited to about 100 bytes.
    fun httpSocketPath(context: Context): String =
            File(context.filesDir, "http.sock").absolutePath

    // Same process as V2RayVpnService, so the Go core's session state is right here.
    // Carries the proxy password: never log the result.
    fun localProxy(): LocalProxyMessage? {
        val proxy = Android.localHTTPProxy() ?: return null
        return LocalProxyMessage(socket = proxy.socket, user = proxy.user, pass = proxy.pass)
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
