package com.slipstream

import org.junit.Assert.assertEquals
import org.junit.Test

class VpnNotificationContentTest {

    @Test
    fun connectedShowsTheServerNameAndNoTraffic() {
        val content = notificationContent(connected = true, serverTitle = "🇩🇪 Germany")

        assertEquals("🇩🇪 Germany", content.title)
        assertEquals("Connected", content.text)
    }

    @Test
    fun connectingSaysSoUnderTheServerName() {
        val content = notificationContent(connected = false, serverTitle = "🇩🇪 Germany")

        assertEquals("🇩🇪 Germany", content.title)
        assertEquals("Connecting…", content.text)
    }

    @Test
    fun withoutAServerNameTheAppNameIsTheTitle() {
        assertEquals("Slipstream", notificationContent(true, null).title)
    }

    @Test
    fun aBlankServerNameCountsAsMissing() {
        assertEquals("Slipstream", notificationContent(true, "  ").title)
        assertEquals("Slipstream", notificationContent(true, "").title)
    }

    @Test
    fun theServerNameIsTrimmed() {
        assertEquals("Germany", notificationContent(true, "  Germany \n").title)
    }
}
