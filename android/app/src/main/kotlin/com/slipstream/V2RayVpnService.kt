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
        private const val TRAFFIC_POLL_INTERVAL_MS = 1000L

        // Inside the TUN subnet (we are 10.0.0.2/24). Nothing answers on 853 here,
        // so automatic Private DNS can't upgrade to DoT and the config's port-53
        // hijack sees every query. Only for configs that hijack DNS themselves:
        // provider rules would send a private address direct, into nowhere.
        private const val TUN_DNS = "10.0.0.1"
        private val PUBLIC_DNS = listOf("1.1.1.1", "1.0.0.1")
    }

    // Debug builds only, while the service runs:
    //   adb shell am broadcast -a com.slipstream.DUMP_HEAP -p com.slipstream [--es name before]
    // writes the core's heap profile to files/heap[-name].pprof (the core checks the name).
    private val heapDumpReceiver =
            object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    try {
                        val name = intent.getStringExtra("name") ?: ""
                        val path = Android.writeHeapProfile(filesDir.absolutePath, name)
                        Log.i("VPN_SERVICE", "Heap profile written: $path")
                    } catch (e: Exception) {
                        Log.w("VPN_SERVICE", "Heap profile failed: ${e.message}")
                    }
                }
            }

    override fun onCreate() {
        super.onCreate()
        if (isDebuggable()) {
            // Exported: the broadcast comes from adb's shell user, not from this app.
            ContextCompat.registerReceiver(
                    this,
                    heapDumpReceiver,
                    IntentFilter(ACTION_DUMP_HEAP),
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

        Log.d("VPN_SERVICE", "Starting service and core...")
        isStopping = false
        startForegroundWithNotification(buildNotification("Подключение…"))
        VpnEventBridge.notifyStatus(VpnStatus.CONNECTING)
        Android.setHandler(VpnEventBridge)
        setupVpn(configJson, geoDir, hijackDns)

        return START_STICKY
    }

    private fun setupVpn(configJson: String, geoDir: String, hijackDns: Boolean) {
        try {
            val dnsServers = if (hijackDns) listOf(TUN_DNS) else PUBLIC_DNS
            val builder =
                    Builder()
                            .addAddress("10.0.0.2", 24)
                            .addAddress("fd00:10:10:10::2", 64)
            dnsServers.forEach { builder.addDnsServer(it) }
            val tunnel =
                    builder
                            .addRoute("0.0.0.0", 0)
                            .addRoute("::", 0)
                            .addDisallowedApplication(packageName)
                            .setSession("Slipstream")
                            .setMtu(1500)
                            .establish()
                            ?: throw Exception("Failed to establish the VPN interface")
            localTunnel = tunnel

            val fd = tunnel.detachFd()
            // Chatty core logs for debug builds only. The flag comes from the
            // build itself (release APKs are never debuggable), not from Dart.
            Android.setVerboseLogs(isDebuggable())
            // The core picks the SOCKS port and credentials itself; they never leave Go.
            Android.start(configJson, fd.toLong(), geoDir)
            Log.d("VPN_SERVICE", "Xray + tun2socks started, fd=$fd, dns=$dnsServers, geoDir=$geoDir")

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

    // Go's own view of its memory (totalBytes, ≈ runtime.MemStats.Sys), not
    // the app process's RSS: the VpnService runs in the same process as the
    // Flutter engine (no android:process override), so process-wide RSS is
    // mostly Skia/Flutter overhead and would wildly overstate what xray-core
    // itself costs. Total only grows (Go rarely hands pages back), so it
    // tracks a live footprint far more steadily than the heap alone, which
    // saws up and down every GC cycle.
    private fun sampleMemoryBytes(): Long? =
            try {
                Android.queryMemory()?.totalBytes
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
        if (isDebuggable()) unregisterReceiver(heapDumpReceiver)
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
