package com.slipstream

import androidx.annotation.StringRes

// What the quick settings tile does and shows, as plain functions: the
// TileService (VpnTileService) only asks the system and carries it out.

enum class TileTapAction {
    // Start the last launch again, without opening the app.
    START,
    // Turn the running VPN off.
    STOP,
    // The tile cannot do it alone (no VPN permission, or no server ever
    // started): the app opens.
    OPEN_APP,
    // The VPN is changing; a second tap would race the first.
    NONE,
}

internal fun tileTapAction(
        status: VpnStatus,
        permissionGranted: Boolean,
        hasSavedLaunch: Boolean,
): TileTapAction =
        when (status) {
            // Blocked: the kill switch holds the traffic, a tap turns the VPN off.
            VpnStatus.CONNECTED, VpnStatus.BLOCKED -> TileTapAction.STOP
            VpnStatus.CONNECTING, VpnStatus.DISCONNECTING -> TileTapAction.NONE
            // After an error the next tap tries again, like a tap in the app.
            VpnStatus.DISCONNECTED, VpnStatus.ERROR ->
                    if (permissionGranted && hasSavedLaunch) TileTapAction.START
                    else TileTapAction.OPEN_APP
        }

enum class TileLook { ACTIVE, INACTIVE }

// The line under the tile's label is either the [serverName] (a name, never translated)
// or a string resource [subtitleRes] that the tile resolves in the user's language; both
// null means no line.
data class TileView(
        val look: TileLook,
        val serverName: String? = null,
        @StringRes val subtitleRes: Int? = null,
)

// Active only while connected; a change reads "Connecting…" and stays inactive.
// [serverTitle] is the server of the last launch, which is the one running.
internal fun tileView(status: VpnStatus, serverTitle: String?): TileView =
        when (status) {
            VpnStatus.CONNECTED -> {
                val name = serverTitle?.trim()?.takeIf { it.isNotEmpty() }
                if (name != null) TileView(TileLook.ACTIVE, serverName = name)
                else TileView(TileLook.ACTIVE, subtitleRes = R.string.notification_connected)
            }
            VpnStatus.BLOCKED -> TileView(TileLook.ACTIVE, subtitleRes = R.string.tile_blocked)
            VpnStatus.CONNECTING ->
                    TileView(TileLook.INACTIVE, subtitleRes = R.string.notification_connecting)
            VpnStatus.DISCONNECTING ->
                    TileView(TileLook.INACTIVE, subtitleRes = R.string.tile_disconnecting)
            VpnStatus.DISCONNECTED, VpnStatus.ERROR -> TileView(TileLook.INACTIVE)
        }
