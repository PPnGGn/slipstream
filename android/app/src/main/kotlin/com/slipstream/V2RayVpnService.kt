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

    // The interface the core runs on. Non-null from the moment it is built until the
    // session ends: that is what "a session is running" means (see startDecision).
    private var localTunnel: ParcelFileDescriptor? = null

    // The kill switch's hold after a failed start: an interface with the tunnel's
    // addresses and routes that nobody reads from, so whatever apps send into it goes
    // nowhere. Replaced by the real interface on Reconnect, closed on Disconnect.
    private var blockingTunnel: ParcelFileDescriptor? = null

    // The launch being worked on: the blocking interface is built from the same one.
    private var activeLaunch: VpnLaunchConfig? = null

    private var notificationPhase = NotificationPhase.CONNECTING

    // guard duplicate stop (onRevoke + onDestroy)
    private var isStopping = false

    private val mainHandler = Handler(Looper.getMainLooper())
    private var trafficPollRunnable: Runnable? = null

    // The server's name for the notification's title; set with every start.
    private var serverTitle: String? = null

    private val launchStore by lazy { VpnLaunchStore.of(this) }

    companion object {
        private const val NOTIFICATION_CHANNEL_ID = "slipstream_vpn_status"
        private const val NOTIFICATION_ID = 1
        // The two the quick settings tile sends (VpnTileService).
        internal const val ACTION_STOP_VPN = "ACTION_STOP_VPN"

        // "Start the last launch again": no config in the intent, it is read from
        // VpnLaunchStore. The caller must use startForegroundService.
        internal const val ACTION_START_LAST = "com.slipstream.START_LAST"
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

        // Who started us and what to do about it is decided by plain functions
        // (VpnStartRules.kt); this only gathers their facts and carries it out.
        val trigger =
                startTriggerFor(intent?.action, hasConfig = intent?.hasExtra("XRAY_CONFIG") == true)
        val saved = launchStore.load()
        val decision =
                startDecision(
                        trigger,
                        sessionRunning = localTunnel != null,
                        savedKillSwitch = saved?.killSwitch,
                        startInterrupted = launchStore.startInterrupted(),
                )
        Log.d("VPN_SERVICE", "Start: trigger=$trigger decision=$decision")

        val launch =
                when (decision) {
                    StartDecision.IGNORE -> {
                        // Started with startForegroundService, which owes the system a
                        // startForeground within seconds, even for a start we ignore.
                        if (trigger == StartTrigger.START_LAST) {
                            startForegroundWithNotification(buildNotification(notificationPhase))
                        }
                        return START_STICKY
                    }
                    StartDecision.NOTHING_TO_START -> {
                        if (trigger == StartTrigger.START_LAST) {
                            startForegroundWithNotification(
                                    buildNotification(NotificationPhase.CONNECTING),
                            )
                            stopForeground(STOP_FOREGROUND_REMOVE)
                        }
                        // Nothing runs and nothing is held: do not sit there started.
                        if (localTunnel == null && blockingTunnel == null) stopSelf()
                        return START_NOT_STICKY
                    }
                    StartDecision.START_SAVED -> saved
                    StartDecision.START_FROM_APP -> launchFromIntent(intent)
                }
        if (launch == null) {
            Log.e("VPN_SERVICE", "No launch to start. Aborting.")
            if (localTunnel == null && blockingTunnel == null) stopSelf()
            return START_NOT_STICKY
        }

        startSession(launch, trigger)
        return START_STICKY
    }

    private fun startSession(launch: VpnLaunchConfig, trigger: StartTrigger) {
        Log.d("VPN_SERVICE", "Starting service and core...")
        isStopping = false
        serverTitle = launch.serverTitle
        activeLaunch = launch
        // Erased when the start ends, one way or the other we handle. If it is still
        // there at the next start, the process died on the way (see startDecision).
        try {
            launchStore.markStarting()
        } catch (e: Exception) {
            Log.w("VPN_SERVICE", "Could not mark the start: ${e.javaClass.simpleName}")
        }
        notificationPhase = NotificationPhase.CONNECTING
        startForegroundWithNotification(buildNotification(NotificationPhase.CONNECTING))
        VpnEventBridge.notifyStatus(VpnStatus.CONNECTING)
        Android.setHandler(VpnEventBridge)
        setupVpn(launch, trigger)
    }

    // The launch the app's intent carries; it is kept as the last one, for the tile
    // and for a restart. Null when the intent has no usable config.
    // The launch holds the server's credentials: log what it is, never what it says.
    private fun launchFromIntent(intent: Intent?): VpnLaunchConfig? {
        val configJson = intent?.getStringExtra("XRAY_CONFIG")
        if (configJson == null) {
            Log.e("VPN_SERVICE", "Config is missing. Aborting.")
            return null
        }
        val launch =
                VpnLaunchConfig(
                        configJson = configJson,
                        geoDir = intent.getStringExtra("GEO_DIR")
                                        ?: java.io.File(filesDir, "geo")
                                                .apply { mkdirs() }
                                                .absolutePath,
                        hijackDns = intent.getBooleanExtra("HIJACK_DNS", false),
                        splitMode =
                                intent.getStringExtra("SPLIT_MODE")?.let {
                                    runCatching { VpnSplitMode.valueOf(it) }.getOrNull()
                                },
                        splitPackages =
                                intent.getStringArrayListExtra("SPLIT_PACKAGES") ?: emptyList(),
                        serverTitle = intent.getStringExtra("SERVER_TITLE"),
                        ipv6 = intent.getBooleanExtra("IPV6", false),
                        killSwitch = intent.getBooleanExtra("KILL_SWITCH", false),
                )
        // A failed save must not stop this start: only the tile loses by it.
        try {
            launchStore.save(launch)
        } catch (e: Exception) {
            Log.w("VPN_SERVICE", "Could not save the launch: ${e.javaClass.simpleName}")
        }
        return launch
    }

    // Builds the VPN interface for a launch: the tunnel's addresses, DNS, routes and
    // split rules. The real tunnel and the kill switch's blocking interface are the
    // same shape, so whichever replaces the other changes nothing for the apps
    // except whether anyone reads their packets. A new interface replaces the one
    // this service had before.
    private fun establishInterface(launch: VpnLaunchConfig): ParcelFileDescriptor {
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
        val dnsServers = if (launch.hijackDns) listOf(network.getDNS4()) else PUBLIC_DNS
        // Without IPv6 the interface has no IPv6 address or route, and Android
        // blocks the whole family (see tunnelShape).
        val shape =
                tunnelShape(
                        network.address4,
                        network.prefix4.toInt(),
                        network.address6,
                        network.prefix6.toInt(),
                        launch.ipv6,
                )
        val builder = Builder()
        shape.addresses.forEach { builder.addAddress(it.address, it.prefix) }
        dnsServers.forEach { builder.addDnsServer(it) }
        // The app itself stays outside the tunnel: the core's own connections
        // must not loop back into it, server ping must measure the direct path,
        // and subscription/geo requests go direct unless they ask for the core's
        // local proxy. applySplitTunnel keeps that true in every mode. Do not drop.
        val split =
                applySplitTunnel(
                        launch.splitMode,
                        launch.splitPackages,
                        packageName,
                        allow = { pkg -> builder.tryAllowApplication(pkg) },
                        disallow = { pkg -> builder.tryDisallowApplication(pkg) },
                )
        logSplitTunnel(launch.splitMode, split)
        shape.routes.forEach { builder.addRoute(it.address, it.prefix) }
        return builder
                .setSession("Slipstream")
                .setMtu(network.getMTU().toInt())
                .establish()
                ?: throw Exception("Failed to establish the VPN interface")
    }

    private fun setupVpn(launch: VpnLaunchConfig, trigger: StartTrigger) {
        try {
            val tunnel = establishInterface(launch)
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
            Android.start(
                    launch.configJson,
                    fd.toLong(),
                    launch.geoDir,
                    VpnQueries.httpSocketPath(this),
            )
            Log.d(
                    "VPN_SERVICE",
                    "Xray + tun2socks started, fd=$fd, hijackDns=${launch.hijackDns}, " +
                            "ipv6=${launch.ipv6}, killSwitch=${launch.killSwitch}, geoDir=${launch.geoDir}",
            )

            // The real interface replaced the blocking one when it was established;
            // what is left of it is a stale handle.
            releaseBlockingTunnel()
            finishStartMark()
            notificationPhase = NotificationPhase.CONNECTED
            val connectedAtMs = System.currentTimeMillis()
            VpnEventBridge.notifyStatus(VpnStatus.CONNECTED, connectedAtEpochMs = connectedAtMs)
            updateNotification(buildNotification(NotificationPhase.CONNECTED))
            startTrafficPolling()
        } catch (e: Exception) {
            Log.e("VPN_SERVICE", "Critical error in setupVpn: ${e.message}")
            // A start that failed in a way we caught is not a crash: the mark goes.
            finishStartMark()
            localTunnel = null
            val reason = e.message ?: "setupVpn failed"
            // A tunnel lost and not coming back is held; a server that never worked
            // is just an error (see shouldBlockOnFailure).
            if (shouldBlockOnFailure(launch.killSwitch, trigger, alreadyBlocked = blockingTunnel != null)) {
                holdBlockingTunnel(launch, reason)
            } else {
                VpnEventBridge.notifyStatus(VpnStatus.ERROR, reason)
                stopVpn(dueToError = true)
            }
        }
    }

    // The kill switch's answer to a failed start: instead of closing the VPN, which
    // would let every app's traffic out the moment the interface is gone, build the
    // interface again and read nothing from it. The user ends it with Reconnect (a
    // new interface replaces this one) or Disconnect (stopVpn closes it).
    private fun holdBlockingTunnel(launch: VpnLaunchConfig, reason: String) {
        try {
            // Nothing of the core may keep running while the traffic is held. Safe to
            // call whether or not a start got far.
            try {
                Android.stop()
            } catch (e: Exception) {
                Log.w("VPN_SERVICE", "Core stop before blocking failed: ${e.message}")
            }
            stopTrafficPolling()
            val blocking = establishInterface(launch)
            val previous = blockingTunnel
            blockingTunnel = blocking
            previous?.closeQuietly()

            notificationPhase = NotificationPhase.BLOCKED
            updateNotification(buildNotification(NotificationPhase.BLOCKED))
            VpnEventBridge.notifyStatus(VpnStatus.BLOCKED, reason)
            Log.w("VPN_SERVICE", "Kill switch: traffic is blocked, reason: $reason")
        } catch (e: Exception) {
            // Not even a blocking interface (the VPN permission is gone, say): the
            // honest thing left is to close the VPN and say it failed.
            Log.e("VPN_SERVICE", "Kill switch could not hold the traffic: ${e.message}")
            VpnEventBridge.notifyStatus(VpnStatus.ERROR, reason)
            stopVpn(dueToError = true)
        }
    }

    private fun releaseBlockingTunnel() {
        blockingTunnel?.closeQuietly()
        blockingTunnel = null
    }

    private fun ParcelFileDescriptor.closeQuietly() {
        try {
            close()
        } catch (e: Exception) {
            Log.w("VPN_SERVICE", "Closing an interface failed: ${e.message}")
        }
    }

    private fun finishStartMark() {
        try {
            launchStore.markStarted()
        } catch (e: Exception) {
            Log.w("VPN_SERVICE", "Could not clear the start mark: ${e.javaClass.simpleName}")
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
                            // The notification does not show traffic: only the app does.
                            VpnEventBridge.notifyTraffic(
                                    stats.uplinkBytes,
                                    stats.downlinkBytes,
                                    sampleMemoryBytes(),
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
        // The user turned the VPN off (or it failed with nothing left to hold): the
        // blocking interface goes with it, and traffic flows as it does without a VPN.
        releaseBlockingTunnel()
        activeLaunch = null

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
        // From Android 12 the system may refuse a foreground start made from the
        // background (a restart after the process died, say). The tunnel is worth more
        // than the notification: log it and carry on.
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.w("VPN_SERVICE", "startForeground refused: ${e.javaClass.simpleName}")
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

    // "Reconnect" starts the saved launch again. The service may be only started, not
    // foreground, so from Android 8 it must be a foreground-service PendingIntent.
    private fun reconnectPendingIntent(): PendingIntent {
        val intent = Intent(this, V2RayVpnService::class.java).setAction(ACTION_START_LAST)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.getForegroundService(this, 3, intent, flags)
        } else {
            PendingIntent.getService(this, 3, intent, flags)
        }
    }

    private fun buildNotification(phase: NotificationPhase): Notification {
        val content = notificationContent(phase, serverTitle)
        val stopIntent = Intent(this, V2RayVpnService::class.java).setAction(ACTION_STOP_VPN)
        val stopPendingIntent =
                PendingIntent.getService(
                        this,
                        0,
                        stopIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
        val builder =
                NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
                        .setContentTitle(content.title)
                        .setContentText(content.text)
                        .setSmallIcon(R.mipmap.ic_launcher)
                        .setContentIntent(openAppPendingIntent())
                        .setOngoing(true)
                        .setOnlyAlertOnce(true)
                        .setPriority(NotificationCompat.PRIORITY_LOW)
        if (content.canReconnect) builder.addAction(0, "Reconnect", reconnectPendingIntent())
        return builder.addAction(0, "Disconnect", stopPendingIntent).build()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        // Created on every start, not only the first: creating a channel that
        // exists changes its name (what the user sees in the system settings)
        // and leaves its importance alone. That is how the old Russian name of
        // an installed app becomes English.
        val channel =
                NotificationChannel(
                        NOTIFICATION_CHANNEL_ID,
                        "VPN status",
                        NotificationManager.IMPORTANCE_LOW,
                )
        manager.createNotificationChannel(channel)
    }
}
