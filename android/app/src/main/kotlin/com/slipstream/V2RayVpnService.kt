package com.slipstream

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
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
        private const val SOCKS_PORT = 10808
        private const val TRAFFIC_POLL_INTERVAL_MS = 1000L
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

        Log.d("VPN_SERVICE", "Starting service and core...")
        isStopping = false
        startForegroundWithNotification(buildNotification("Подключение…"))
        VpnEventBridge.notifyStatus(VpnStatus.CONNECTING)
        Android.setHandler(VpnEventBridge)
        setupVpn(configJson)

        return START_STICKY
    }

    private fun setupVpn(configJson: String) {
        try {
            val tunnel =
                    Builder()
                            .addAddress("10.0.0.2", 24)
                            .addAddress("fd00:10:10:10::2", 64)
                            .addDnsServer("1.1.1.1")
                            .addDnsServer("1.0.0.1")
                            .addRoute("0.0.0.0", 0)
                            .addRoute("::", 0)
                            .addDisallowedApplication(packageName)
                            .setSession("Slipstream")
                            .setMtu(1500)
                            .establish()
                            ?: throw Exception("Failed to establish the VPN interface")
            localTunnel = tunnel

            val fd = tunnel.detachFd()
            Android.start(configJson, fd.toLong(), SOCKS_PORT.toLong())
            Log.d("VPN_SERVICE", "Xray + tun2socks started, fd=$fd, port=$SOCKS_PORT")

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
                            VpnEventBridge.notifyTraffic(stats.uplinkBytes, stats.downlinkBytes)
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
