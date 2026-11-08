package com.slipstream

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

// The texts themselves live in res/values*/strings.xml, one file per language; these
// tests pin which text each phase picks, so a translation cannot change what is said.
class VpnNotificationContentTest {

    private fun content(phase: NotificationPhase, title: String? = "🇩🇪 Germany") =
            notificationContent(phase, title)

    @Test
    fun connectedShowsTheServerNameAndNoTraffic() {
        val content = content(NotificationPhase.CONNECTED)

        assertEquals("🇩🇪 Germany", content.title)
        assertEquals(R.string.notification_connected, content.text)
    }

    @Test
    fun connectingSaysSoUnderTheServerName() {
        val content = content(NotificationPhase.CONNECTING)

        assertEquals("🇩🇪 Germany", content.title)
        assertEquals(R.string.notification_connecting, content.text)
    }

    @Test
    fun blockedSaysTheTrafficIsBlocked() {
        val content = content(NotificationPhase.BLOCKED)

        assertEquals("🇩🇪 Germany", content.title)
        assertEquals(R.string.notification_blocked, content.text)
    }

    @Test
    fun everyPhaseHasItsOwnText() {
        val texts = NotificationPhase.values().map { content(it).text }

        assertEquals(texts.size, texts.toSet().size)
    }

    @Test
    fun onlyTheBlockedNotificationOffersReconnect() {
        assertTrue(content(NotificationPhase.BLOCKED).canReconnect)
        assertFalse(content(NotificationPhase.CONNECTED).canReconnect)
        assertFalse(content(NotificationPhase.CONNECTING).canReconnect)
    }

    // The service puts the app name in its place, in the language of the moment.
    @Test
    fun withoutAServerNameThereIsNoTitle() {
        assertNull(content(NotificationPhase.CONNECTED, null).title)
    }

    @Test
    fun aBlankServerNameCountsAsMissing() {
        assertNull(content(NotificationPhase.CONNECTED, "  ").title)
        assertNull(content(NotificationPhase.CONNECTED, "").title)
    }

    @Test
    fun theServerNameIsTrimmed() {
        assertEquals("Germany", content(NotificationPhase.CONNECTED, "  Germany \n").title)
    }
}
