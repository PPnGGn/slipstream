package com.slipstream

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.slipstream.android.Android

class V2RayVpnService : VpnService() {

    private var localTunnel: ParcelFileDescriptor? = null

    // guard duplicate stop (onRevoke + onDestroy)
    private var isStopping = false

    private val mainHandler = Handler(Looper.getMainLooper())
    private var trafficPollRunnable: Runnable? = null

    companion object {
        private const val NOTIFICATION_CHANNEL_ID = "slipstream_vpn_status"
        private const val NOTIFICATION_ID = 1
        private const val ACTION_STOP_VPN = "ACTION_STOP_VPN"
        private const val ACTION_DUMP_HEAP = "com.slipstream.DUMP_HEAP"
        private const val ACTION_SET_GC = "com.slipstream.SET_GC"
        private const val ACTION_MEM_LOG = "com.slipstream.MEM_LOG"
        private const val TRAFFIC_POLL_INTERVAL_MS = 1000L

        // For configs that route DNS their own way. The other choice is the DNS
        // address inside the TUN subnet that the core draws with the addresses
        // (TunnelNetwork.dns4), see setupVpn.
        private val PUBLIC_DNS = listOf("1.1.1.1", "1.0.0.1")
    }

    // Debug builds only, while the service runs:
    //   adb shell am broadcast -a com.slipstream.DUMP_HEAP -p com.slipstream [--es name before]
    // writes the core's goroutine stacks to files/goroutines[-name].txt and its
    // heap profile to files/heap[-name].pprof (the core checks the name);
    //   adb shell am broadcast -a com.slipstream.SET_GC -p com.slipstream --ei percent 50 [--ei limit_mb 80]
    // changes the core's GC settings on the live session (limit_mb 0 or absent = no limit);
    //   adb shell am broadcast -a com.slipstream.MEM_LOG -p com.slipstream --ez on true|false
    // turns the core's "mem:" logcat line (every 3 s, tag GoLog) on or off; it stays on across switches.
    private val debugReceiver =
            object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    try {
                        when (intent.action) {
                            ACTION_DUMP_HEAP -> {
                                val name = intent.getStringExtra("name") ?: ""
                                val dir = filesDir.absolutePath
                                val goroutines = Android.writeGoroutineDump(dir, name)
                                val heap = Android.writeHeapProfile(dir, name)
                                Log.i("VPN_SERVICE", "Dumps written: $goroutines, $heap")
                            }
                            ACTION_SET_GC -> {
                                val percent = intent.getIntExtra("percent", 100)
                                val limitMb = intent.getIntExtra("limit_mb", 0)
                                Android.setGCTuning(percent.toLong(), limitMb.toLong())
                                Log.i("VPN_SERVICE", "GC tuning set: gogc=$percent limit_mb=$limitMb")
                            }
                            ACTION_MEM_LOG -> {
                                val on = intent.getBooleanExtra("on", true)
                                Android.setMemoryLog(on)
                                Log.i("VPN_SERVICE", "Memory log ${if (on) "on" else "off"}")
                            }
                        }
                    } catch (e: Exception) {
                        Log.w("VPN_SERVICE", "Debug command ${intent.action} failed: ${e.message}")
                    }
                }
            }

    override fun onCreate() {
        super.onCreate()
        if (isDebuggable()) {
            // Exported: the broadcast comes from adb's shell user, not from this app.
            ContextCompat.registerReceiver(
                    this,
                    debugReceiver,
                    IntentFilter().apply {
                        addAction(ACTION_DUMP_HEAP)
                        addAction(ACTION_SET_GC)
                        addAction(ACTION_MEM_LOG)
                    },
                    ContextCompat.RECEIVER_EXPORTED,
            )
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP_VPN) {
            Log.d("VPN_SERVICE", "Stopping service by request...")
            stopVpn()
            return START_NOT_STICKY
        }

        val configJson = intent?.getStringExtra("XRAY_CONFIG")
        if (configJson == null) {
            Log.e("VPN_SERVICE", "Config is missing. Aborting.")
            return START_NOT_STICKY
        }
        val geoDir = intent.getStringExtra("GEO_DIR")
                ?: java.io.File(filesDir, "geo").apply { mkdirs() }.absolutePath
        val hijackDns = intent.getBooleanExtra("HIJACK_DNS", false)
        val splitMode =
                intent.getStringExtra("SPLIT_MODE")?.let {
                    runCatching { VpnSplitMode.valueOf(it) }.getOrNull()
                }
        val splitPackages = intent.getStringArrayListExtra("SPLIT_PACKAGES") ?: emptyList<String>()

        Log.d("VPN_SERVICE", "Starting service and core...")
        isStopping = false
        startForegroundWithNotification(buildNotification("Подключение…"))
        VpnEventBridge.notifyStatus(VpnStatus.CONNECTING)
        Android.setHandler(VpnEventBridge)
        setupVpn(configJson, geoDir, hijackDns, splitMode, splitPackages)

        return START_STICKY
    }

    private fun setupVpn(
            configJson: String,
            geoDir: String,
            hijackDns: Boolean,
            splitMode: VpnSplitMode?,
            splitPackages: List<String>,
    ) {
        try {
            // A network of its own for every session: the same addresses every time
            // are something another app can read off the interface and look for.
            // Its MTU is the core's, take it as it is.
            val network = Android.newTunnelNetwork()
            // Inside the TUN subnet nothing answers on 853, so automatic Private DNS
            // can't upgrade to DoT and the config's port-53 hijack sees every query.
            // Only for configs that hijack DNS themselves: provider rules would send a
            // private address direct, into nowhere.
            // getDNS4() and getMTU() are called as methods: Kotlin turns the all-capital
            // names gomobile makes from DNS4 and MTU into properties by its own rules.
            val dnsServers = if (hijackDns) listOf(network.getDNS4()) else PUBLIC_DNS
            val builder =
                    Builder()
                            .addAddress(network.address4, network.prefix4.toInt())
                            .addAddress(network.address6, network.prefix6.toInt())
            dnsServers.forEach { builder.addDnsServer(it) }
            // The app itself stays outside the tunnel: the core's own connections
            // must not loop back into it, server ping must measure the direct path,
            // and subscription/geo requests go direct unless they ask for the core's
            // local proxy. applySplitTunnel keeps that true in every mode. Do not drop.
            val split =
                    applySplitTunnel(
                            splitMode,
                            splitPackages,
                            packageName,
                            allow = { pkg -> builder.tryAllowApplication(pkg) },
                            disallow = { pkg -> builder.tryDisallowApplication(pkg) },
                    )
            logSplitTunnel(splitMode, split)
            val tunnel =
                    builder
                            .addRoute("0.0.0.0", 0)
                            .addRoute("::", 0)
                            .setSession("Slipstream")
                            .setMtu(network.getMTU().toInt())
                            .establish()
                            ?: throw Exception("Failed to establish the VPN interface")
            localTunnel = tunnel

            val fd = tunnel.detachFd()
            // Chatty core logs for debug builds only. The flag comes from the
            // build itself (release APKs are never debuggable), not from Dart.
            Android.setVerboseLogs(isDebuggable())
            // The core listens on no port at all. The only listener is the HTTP proxy
            // for the app's own requests, on a Unix socket in the app's private
            // directory; its password is picked by the core (see VpnQueries.localProxy).
            //
            // This runs on the main thread, which is also the one Dart runs on, so the
            // UI waits for it. Measured on an A015 (Android 16), from onStartCommand to
            // the return of Android.start: 40-200 ms, 540 ms for the first connect after
            // the geo databases were installed; Android.stop takes 50-90 ms. The limits are
            // seconds (5 s of a blocked input), so it stays here: a thread would need
            // a guard for a stop that arrives before the start is done.
            Android.start(configJson, fd.toLong(), geoDir, VpnQueries.httpSocketPath(this))
            Log.d("VPN_SERVICE", "Xray + tun2socks started, fd=$fd, hijackDns=$hijackDns, geoDir=$geoDir")

            val connectedAtMs = System.currentTimeMillis()
            VpnEventBridge.notifyStatus(VpnStatus.CONNECTED, connectedAtEpochMs = connectedAtMs)
            updateNotification(buildNotification("Подключено"))
            startTrafficPolling()
        } catch (e: Exception) {
            Log.e("VPN_SERVICE", "Critical error in setupVpn: ${e.message}")
            VpnEventBridge.notifyStatus(VpnStatus.ERROR, e.message ?: "setupVpn failed")
            stopVpn(dueToError = true)
        }
    }

    // An app can be uninstalled after the user picked it: the Builder then throws
    // NameNotFoundException, which must not stop the tunnel from coming up.
    private fun Builder.tryAllowApplication(pkg: String): Boolean =
            try {
                addAllowedApplication(pkg)
                true
            } catch (e: PackageManager.NameNotFoundException) {
                false
            }

    private fun Builder.tryDisallowApplication(pkg: String): Boolean =
            try {
                addDisallowedApplication(pkg)
                true
            } catch (e: PackageManager.NameNotFoundException) {
                false
            }

    private fun logSplitTunnel(mode: VpnSplitMode?, outcome: SplitTunnelOutcome) {
        Log.d(
                "VPN_SERVICE",
                "Split tunnel: mode=$mode applied=${outcome.applied} skipped=${outcome.skipped}",
        )
        if (outcome.fellBackToFullTunnel) {
            Log.w("VPN_SERVICE", "Split tunnel: no picked app is installed, tunneling every app")
        }
    }

    private fun isDebuggable(): Boolean =
            (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    private fun startTrafficPolling() {
        stopTrafficPolling()
        val runnable =
                object : Runnable {
                    override fun run() {
                        val stats =
                                try {
                                    Android.queryTraffic()
                                } catch (e: Exception) {
                                    Log.w("VPN_SERVICE", "queryTraffic failed: ${e.message}")
                                    null
                                }
                        if (stats != null) {
                            VpnEventBridge.notifyTraffic(
                                    stats.uplinkBytes,
                                    stats.downlinkBytes,
                                    sampleMemoryBytes(),
                            )
                            updateNotification(
                                    buildNotification(
                                            "↑ ${formatBytes(stats.uplinkBytes)} · ↓ ${formatBytes(stats.downlinkBytes)}",
                                    ),
                            )
                        }
                        mainHandler.postDelayed(this, TRAFFIC_POLL_INTERVAL_MS)
                    }
                }
        trafficPollRunnable = runnable
        mainHandler.post(runnable)
    }

    private fun stopTrafficPolling() {
        trafficPollRunnable?.let { mainHandler.removeCallbacks(it) }
        trafficPollRunnable = null
    }

    // What the core costs the phone right now: memory the Go runtime holds
    // from the OS (retainedBytes = mapped minus handed back). Not the app
    // process's RSS: the VpnService runs in the same process as the Flutter
    // engine (no android:process override), so process-wide RSS is mostly
    // Skia/Flutter overhead. Not totalBytes either: that one almost never
    // drops and carries a heavy session's record into the next one.
    // Retained does drop, with a lag — Go returns freed pages gradually.
    private fun sampleMemoryBytes(): Long? =
            try {
                Android.queryMemory()?.retainedBytes
            } catch (e: Exception) {
                Log.w("VPN_SERVICE", "queryMemory failed: ${e.message}")
                null
            }

    // another VPN took over
    override fun onRevoke() {
        Log.w("VPN_SERVICE", "VPN revoked by system (another VPN started). Emergency shutdown.")
        stopVpn()
        super.onRevoke()
    }

    private fun stopVpn(dueToError: Boolean = false) {
        if (isStopping) return
        isStopping = true

        Log.d("VPN_SERVICE", "Shutting down everything...")
        if (!dueToError) VpnEventBridge.notifyStatus(VpnStatus.DISCONNECTING)
        stopTrafficPolling()

        try {
            // core closes the TUN fd on the native side
            Android.stop()
        } catch (e: Exception) {
            Log.e("VPN_SERVICE", "Failed to stop core: ${e.message}")
        }

        localTunnel = null

        if (!dueToError) VpnEventBridge.notifyStatus(VpnStatus.DISCONNECTED)

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopVpn()
        if (isDebuggable()) unregisterReceiver(debugReceiver)
    }

    // The system is short on memory or the UI went to the background: hand back
    // what the core holds but does not use. Any level will do; the call returns
    // at once and the work runs in Go.
    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        Android.freeMemory()
    }

    // Foreground notification

    private fun startForegroundWithNotification(notification: Notification) {
        ensureNotificationChannel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification(notification: Notification) {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun openAppPendingIntent(): PendingIntent? {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: return null
        return PendingIntent.getActivity(
                this,
                1,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun buildNotification(statusText: String): Notification {
        val stopIntent = Intent(this, V2RayVpnService::class.java).setAction(ACTION_STOP_VPN)
        val stopPendingIntent =
                PendingIntent.getService(
                        this,
                        0,
                        stopIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
                .setContentTitle("Slipstream")
                .setContentText(statusText)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(openAppPendingIntent())
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .addAction(0, "Отключить", stopPendingIntent)
                .build()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(NOTIFICATION_CHANNEL_ID) != null) return
        val channel =
                NotificationChannel(
                        NOTIFICATION_CHANNEL_ID,
                        "Статус VPN",
                        NotificationManager.IMPORTANCE_LOW,
                )
        manager.createNotificationChannel(channel)
    }

    private fun formatBytes(bytes: Long): String {
        if (bytes < 1024) return "$bytes Б"
        val units = arrayOf("КБ", "МБ", "ГБ", "ТБ")
        var value = bytes / 1024.0
        var unitIndex = 0
        while (value >= 1024.0 && unitIndex < units.size - 1) {
            value /= 1024.0
            unitIndex++
        }
        return String.format("%.1f %s", value, units[unitIndex])
    }
}
