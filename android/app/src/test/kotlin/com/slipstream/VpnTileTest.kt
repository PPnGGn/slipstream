package com.slipstream

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class VpnTileTest {

    private fun tap(
            status: VpnStatus,
            permission: Boolean = true,
            saved: Boolean = true,
    ) = tileTapAction(status, permission, saved)

    @Test
    fun aTapOnAnActiveTileTurnsTheVpnOff() {
        assertEquals(TileTapAction.STOP, tap(VpnStatus.CONNECTED))
        // Stopping needs neither the permission nor the saved launch.
        assertEquals(TileTapAction.STOP, tap(VpnStatus.CONNECTED, permission = false, saved = false))
    }

    @Test
    fun aTapOnAnInactiveTileTurnsTheVpnOn() {
        assertEquals(TileTapAction.START, tap(VpnStatus.DISCONNECTED))
    }

    @Test
    fun aFailedLastTryCanBeTriedAgain() {
        assertEquals(TileTapAction.START, tap(VpnStatus.ERROR))
    }

    @Test
    fun withoutThePermissionTheAppOpensToAskForIt() {
        assertEquals(TileTapAction.OPEN_APP, tap(VpnStatus.DISCONNECTED, permission = false))
    }

    @Test
    fun withoutASavedLaunchTheAppOpensToPickAServer() {
        assertEquals(TileTapAction.OPEN_APP, tap(VpnStatus.DISCONNECTED, saved = false))
        assertEquals(TileTapAction.OPEN_APP, tap(VpnStatus.ERROR, saved = false))
    }

    @Test
    fun whileTheVpnIsChangingATapDoesNothing() {
        // A second tap in the middle of a change would race the first one.
        assertEquals(TileTapAction.NONE, tap(VpnStatus.CONNECTING))
        assertEquals(TileTapAction.NONE, tap(VpnStatus.DISCONNECTING))
        assertEquals(TileTapAction.NONE, tap(VpnStatus.CONNECTING, permission = false, saved = false))
    }

    @Test
    fun connectedIsActiveAndNamesTheServer() {
        val view = tileView(VpnStatus.CONNECTED, "🇩🇪 Germany")

        assertEquals(TileLook.ACTIVE, view.look)
        assertEquals("🇩🇪 Germany", view.subtitle)
    }

    @Test
    fun connectedWithoutAKnownServerSaysConnected() {
        assertEquals("Connected", tileView(VpnStatus.CONNECTED, null).subtitle)
        assertEquals("Connected", tileView(VpnStatus.CONNECTED, "  ").subtitle)
    }

    @Test
    fun aChangeIsInactiveAndSaysWhat() {
        assertEquals(TileLook.INACTIVE, tileView(VpnStatus.CONNECTING, "x").look)
        assertEquals("Connecting…", tileView(VpnStatus.CONNECTING, "x").subtitle)
        assertEquals(TileLook.INACTIVE, tileView(VpnStatus.DISCONNECTING, "x").look)
        assertEquals("Disconnecting…", tileView(VpnStatus.DISCONNECTING, "x").subtitle)
    }

    @Test
    fun offIsInactiveWithNoSubtitle() {
        assertEquals(TileLook.INACTIVE, tileView(VpnStatus.DISCONNECTED, "x").look)
        assertNull(tileView(VpnStatus.DISCONNECTED, "x").subtitle)
        assertEquals(TileLook.INACTIVE, tileView(VpnStatus.ERROR, "x").look)
        assertNull(tileView(VpnStatus.ERROR, "x").subtitle)
    }
}
