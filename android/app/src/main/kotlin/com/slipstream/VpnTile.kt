package com.slipstream

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
            VpnStatus.CONNECTED -> TileTapAction.STOP
            VpnStatus.CONNECTING, VpnStatus.DISCONNECTING -> TileTapAction.NONE
            // After an error the next tap tries again, like a tap in the app.
            VpnStatus.DISCONNECTED, VpnStatus.ERROR ->
                    if (permissionGranted && hasSavedLaunch) TileTapAction.START
                    else TileTapAction.OPEN_APP
        }

enum class TileLook { ACTIVE, INACTIVE }

data class TileView(val look: TileLook, val subtitle: String?)

// Active only while connected; a change reads "Connecting…" and stays inactive.
// [serverTitle] is the server of the last launch, which is the one running.
internal fun tileView(status: VpnStatus, serverTitle: String?): TileView =
        when (status) {
            VpnStatus.CONNECTED ->
                    TileView(
                            TileLook.ACTIVE,
                            serverTitle?.trim()?.takeIf { it.isNotEmpty() } ?: "Connected",
                    )
            VpnStatus.CONNECTING -> TileView(TileLook.INACTIVE, "Connecting…")
            VpnStatus.DISCONNECTING -> TileView(TileLook.INACTIVE, "Disconnecting…")
            VpnStatus.DISCONNECTED, VpnStatus.ERROR -> TileView(TileLook.INACTIVE, null)
        }
