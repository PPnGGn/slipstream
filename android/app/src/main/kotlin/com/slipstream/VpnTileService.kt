package com.slipstream

import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import androidx.core.content.ContextCompat

// The quick settings tile: turns the VPN on and off from the notification shade.
// What it does and shows is decided by plain functions (VpnTile.kt); this class
// asks the system and carries it out. It lives in the app's process, the same as
// V2RayVpnService, so VpnEventBridge has the current status right here.
class VpnTileService : TileService() {

    private val mainHandler = Handler(Looper.getMainLooper())

    // Status changes come from the service's thread, a tile is updated on the main one.
    private val statusListener: (VpnStatusMessage) -> Unit = { message ->
        mainHandler.post { render(message.status) }
    }

    // Called while the tile is visible: the shade is open.
    override fun onStartListening() {
        super.onStartListening()
        VpnEventBridge.addStatusListener(statusListener)
        render(VpnEventBridge.currentStatus().status)
    }

    override fun onStopListening() {
        VpnEventBridge.removeStatusListener(statusListener)
        super.onStopListening()
    }

    override fun onClick() {
        super.onClick()
        val status = VpnEventBridge.currentStatus().status
        val action =
                tileTapAction(
                        status = status,
                        // null means the permission is already granted.
                        permissionGranted = VpnService.prepare(this) == null,
                        hasSavedLaunch = VpnLaunchStore.of(this).exists(),
                )
        Log.d("VPN_TILE", "Tap: status=$status action=$action")

        when (action) {
            TileTapAction.START ->
                    // startForegroundService: the service is not running, and from
                    // the background (the shade over another app) only this is allowed.
                    ContextCompat.startForegroundService(
                            this,
                            Intent(this, V2RayVpnService::class.java)
                                    .setAction(V2RayVpnService.ACTION_START_LAST),
                    )
            TileTapAction.STOP ->
                    startService(
                            Intent(this, V2RayVpnService::class.java)
                                    .setAction(V2RayVpnService.ACTION_STOP_VPN),
                    )
            TileTapAction.OPEN_APP -> openApp()
            TileTapAction.NONE -> Unit
        }
    }

    private fun render(status: VpnStatus) {
        val tile = qsTile ?: return
        val view = tileView(status, VpnLaunchStore.of(this).load()?.serverTitle)
        tile.state = if (view.look == TileLook.ACTIVE) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = "Slipstream"
        // The line under the label exists from Android 10.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) tile.subtitle = view.subtitle
        tile.updateTile()
    }

    // Closes the shade and opens the app. From Android 14 the intent goes in a
    // PendingIntent, the Intent form is deprecated.
    @Suppress("DEPRECATION")
    private fun openApp() {
        val launch =
                packageManager.getLaunchIntentForPackage(packageName)?.apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                        ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(
                    PendingIntent.getActivity(
                            this,
                            2,
                            launch,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
            )
        } else {
            startActivityAndCollapse(launch)
        }
    }
}
