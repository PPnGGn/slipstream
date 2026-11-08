package com.slipstream

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ConnectionAlertTest {

    private val allOn = AlertPrefs(trafficBlocked = true, startFailed = true)

    private fun after(
            blocked: Boolean,
            trigger: StartTrigger,
            prefs: AlertPrefs = allOn,
    ) = alertAfterFailure(blocked, trigger, prefs)

    // Traffic held by the kill switch is the worst case: the user must hear of it
    // whoever started the attempt, the app included (it may be in the background).
    @Test
    fun blockedTrafficAlwaysAlertsWhenTheSwitchIsOn() {
        for (trigger in StartTrigger.values()) {
            assertEquals(ConnectionAlert.TRAFFIC_BLOCKED, after(blocked = true, trigger = trigger))
        }
    }

    @Test
    fun blockedTrafficIsSilentWhenTheSwitchIsOff() {
        val prefs = AlertPrefs(trafficBlocked = false, startFailed = true)

        for (trigger in StartTrigger.values()) {
            assertNull(after(blocked = true, trigger = trigger, prefs = prefs))
        }
    }

    // The tile, the system (Always-on) and a restart start the VPN quietly: nobody looks
    // at a screen, so the failure needs a voice.
    @Test
    fun aFailedStartWithoutTheAppAlerts() {
        for (trigger in listOf(
                StartTrigger.START_LAST,
                StartTrigger.SYSTEM,
                StartTrigger.RESTART,
                StartTrigger.OTHER,
        )) {
            assertEquals(ConnectionAlert.START_FAILED, after(blocked = false, trigger = trigger))
        }
    }

    // A start the user made in the app shows its error on the main screen.
    @Test
    fun aFailedStartFromTheAppDoesNotAlert() {
        assertNull(after(blocked = false, trigger = StartTrigger.APP))
    }

    @Test
    fun aFailedStartIsSilentWhenItsSwitchIsOff() {
        val prefs = AlertPrefs(trafficBlocked = true, startFailed = false)

        assertNull(after(blocked = false, trigger = StartTrigger.START_LAST, prefs = prefs))
        // The other switch is unaffected.
        assertEquals(
                ConnectionAlert.TRAFFIC_BLOCKED,
                after(blocked = true, trigger = StartTrigger.START_LAST, prefs = prefs),
        )
    }

    @Test
    fun theTwoAlertsSayDifferentThings() {
        val blocked = alertContent(ConnectionAlert.TRAFFIC_BLOCKED)
        val failed = alertContent(ConnectionAlert.START_FAILED)

        assertNotEquals(blocked.title, failed.title)
        assertNotEquals(blocked.text, failed.text)
        assertEquals(R.string.alert_blocked_title, blocked.title)
        assertEquals(R.string.alert_start_failed_title, failed.title)
    }

    // Only the blocked one can be answered on the spot: Reconnect starts the saved
    // launch again. After a failed start the reason is in the app.
    @Test
    fun onlyTheBlockedAlertOffersReconnect() {
        assertTrue(alertContent(ConnectionAlert.TRAFFIC_BLOCKED).canReconnect)
        assertFalse(alertContent(ConnectionAlert.START_FAILED).canReconnect)
    }
}
