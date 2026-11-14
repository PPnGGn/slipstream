package com.slipstream

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

// The core says the tunnel died under a running session (StatusHandler.OnTunnelLost).
// What the service does about it is decided by these plain functions.
class TunnelLossTest {

    private val allOn = AlertPrefs(trafficBlocked = true, startFailed = true)

    // --- tunnelLostAction ---

    @Test
    fun withTheKillSwitchTheTrafficIsHeld() {
        assertEquals(
                TunnelLostAction.HOLD,
                tunnelLostAction(VpnStatus.CONNECTED, stopping = false, killSwitch = true),
        )
    }

    @Test
    fun withoutTheKillSwitchTheVpnIsClosedWithAnError() {
        assertEquals(
                TunnelLostAction.CLOSE,
                tunnelLostAction(VpnStatus.CONNECTED, stopping = false, killSwitch = false),
        )
    }

    // The core also reports the end of a tunnel we stop ourselves, from another
    // thread and a moment late; a loss is only a loss of a connected VPN.
    @Test
    fun aStoppingServiceIgnoresIt() {
        for (killSwitch in listOf(true, false)) {
            assertEquals(
                    TunnelLostAction.IGNORE,
                    tunnelLostAction(VpnStatus.CONNECTED, stopping = true, killSwitch = killSwitch),
            )
        }
    }

    @Test
    fun onlyAConnectedVpnCanLoseItsTunnel() {
        for (status in VpnStatus.values()) {
            if (status == VpnStatus.CONNECTED) continue
            for (killSwitch in listOf(true, false)) {
                assertEquals(
                        status.name,
                        TunnelLostAction.IGNORE,
                        tunnelLostAction(status, stopping = false, killSwitch = killSwitch),
                )
            }
        }
    }

    // --- alertAfterTunnelLoss ---

    @Test
    fun aHeldTunnelAlertsAsBlockedTraffic() {
        assertEquals(
                ConnectionAlert.TRAFFIC_BLOCKED,
                alertAfterTunnelLoss(TunnelLostAction.HOLD, allOn),
        )
    }

    @Test
    fun aClosedTunnelAlertsAsALostTunnel() {
        assertEquals(
                ConnectionAlert.TUNNEL_LOST,
                alertAfterTunnelLoss(TunnelLostAction.CLOSE, allOn),
        )
    }

    @Test
    fun nothingToDoMeansNoAlert() {
        assertNull(alertAfterTunnelLoss(TunnelLostAction.IGNORE, allOn))
    }

    @Test
    fun eachAlertFollowsItsOwnSwitch() {
        val noBlocked = AlertPrefs(trafficBlocked = false, startFailed = true)
        val noLost = AlertPrefs(trafficBlocked = true, startFailed = true, tunnelLost = false)

        assertNull(alertAfterTunnelLoss(TunnelLostAction.HOLD, noBlocked))
        assertEquals(
                ConnectionAlert.TUNNEL_LOST,
                alertAfterTunnelLoss(TunnelLostAction.CLOSE, noBlocked),
        )
        assertNull(alertAfterTunnelLoss(TunnelLostAction.CLOSE, noLost))
        assertEquals(
                ConnectionAlert.TRAFFIC_BLOCKED,
                alertAfterTunnelLoss(TunnelLostAction.HOLD, noLost),
        )
    }

    // The tunnel is gone, but the saved launch is still good: one tap starts it again.
    @Test
    fun theLostTunnelAlertOffersReconnectAndHasItsOwnText() {
        val lost = alertContent(ConnectionAlert.TUNNEL_LOST)

        assertTrue(lost.canReconnect)
        assertEquals(R.string.alert_tunnel_lost_title, lost.title)
        assertEquals(R.string.alert_tunnel_lost_text, lost.text)
        assertNotEquals(alertContent(ConnectionAlert.TRAFFIC_BLOCKED).title, lost.title)
        assertFalse(lost.title == alertContent(ConnectionAlert.START_FAILED).title)
    }
}
