package com.slipstream

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VpnNotificationContentTest {

    private fun content(phase: NotificationPhase, title: String? = "🇩🇪 Germany") =
            notificationContent(phase, title)

    @Test
    fun connectedShowsTheServerNameAndNoTraffic() {
        val content = content(NotificationPhase.CONNECTED)

        assertEquals("🇩🇪 Germany", content.title)
        assertEquals("Connected", content.text)
    }

    @Test
    fun connectingSaysSoUnderTheServerName() {
        val content = content(NotificationPhase.CONNECTING)

        assertEquals("🇩🇪 Germany", content.title)
        assertEquals("Connecting…", content.text)
    }

    @Test
    fun blockedSaysTheTrafficIsBlocked() {
        val content = content(NotificationPhase.BLOCKED)

        assertEquals("🇩🇪 Germany", content.title)
        assertEquals("Connection lost · traffic blocked", content.text)
    }

    @Test
    fun onlyTheBlockedNotificationOffersReconnect() {
        assertTrue(content(NotificationPhase.BLOCKED).canReconnect)
        assertFalse(content(NotificationPhase.CONNECTED).canReconnect)
        assertFalse(content(NotificationPhase.CONNECTING).canReconnect)
    }

    @Test
    fun withoutAServerNameTheAppNameIsTheTitle() {
        assertEquals("Slipstream", content(NotificationPhase.CONNECTED, null).title)
    }

    @Test
    fun aBlankServerNameCountsAsMissing() {
        assertEquals("Slipstream", content(NotificationPhase.CONNECTED, "  ").title)
        assertEquals("Slipstream", content(NotificationPhase.CONNECTED, "").title)
    }

    @Test
    fun theServerNameIsTrimmed() {
        assertEquals("Germany", content(NotificationPhase.CONNECTED, "  Germany \n").title)
    }
}
