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
    fun aTapWhileTrafficIsBlockedTurnsTheVpnOff() {
        // The kill switch is holding the traffic: a tap lets the user out of it, as the
        // ring in the app does.
        assertEquals(TileTapAction.STOP, tap(VpnStatus.BLOCKED))
        assertEquals(TileTapAction.STOP, tap(VpnStatus.BLOCKED, permission = false, saved = false))
    }

    @Test
    fun theTileIsActiveWhileTrafficIsBlocked() {
        val view = tileView(VpnStatus.BLOCKED, "🇩🇪 Germany")

        assertEquals(TileLook.ACTIVE, view.look)
        assertEquals(R.string.tile_blocked, view.subtitleRes)
        assertNull(view.serverName)
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
        assertEquals("🇩🇪 Germany", view.serverName)
        assertNull(view.subtitleRes)
    }

    @Test
    fun connectedWithoutAKnownServerSaysConnected() {
        for (title in listOf(null, "  ")) {
            val view = tileView(VpnStatus.CONNECTED, title)

            assertNull(view.serverName)
            assertEquals(R.string.notification_connected, view.subtitleRes)
        }
    }

    @Test
    fun aChangeIsInactiveAndSaysWhat() {
        assertEquals(TileLook.INACTIVE, tileView(VpnStatus.CONNECTING, "x").look)
        assertEquals(R.string.notification_connecting, tileView(VpnStatus.CONNECTING, "x").subtitleRes)
        assertEquals(TileLook.INACTIVE, tileView(VpnStatus.DISCONNECTING, "x").look)
        assertEquals(R.string.tile_disconnecting, tileView(VpnStatus.DISCONNECTING, "x").subtitleRes)
    }

    @Test
    fun offIsInactiveWithNoSubtitle() {
        for (status in listOf(VpnStatus.DISCONNECTED, VpnStatus.ERROR)) {
            val view = tileView(status, "x")

            assertEquals(TileLook.INACTIVE, view.look)
            assertNull(view.subtitleRes)
            assertNull(view.serverName)
        }
    }
}
