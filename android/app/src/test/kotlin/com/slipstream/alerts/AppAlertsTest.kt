package com.slipstream.alerts

import com.slipstream.R
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AppAlertsTest {

    @Test
    fun everyKindHasItsOwnTitleAndText() {
        val contents = AppAlertKind.values().map { appAlertContent(it) }

        assertEquals(contents.size, contents.map { it.title }.toSet().size)
        assertEquals(contents.size, contents.map { it.text }.toSet().size)
    }

    @Test
    fun theTextsAreTheOnesOfTheKind() {
        assertEquals(R.string.alert_sub_failed_title, appAlertContent(AppAlertKind.SUBSCRIPTION_FAILED).title)
        assertEquals(R.string.alert_sub_expired_title, appAlertContent(AppAlertKind.SUBSCRIPTION_EXPIRED).title)
        assertEquals(R.string.alert_traffic_exhausted_title, appAlertContent(AppAlertKind.TRAFFIC_EXHAUSTED).title)
    }

    // "1 day" and "3 days" are different words in Russian and in English; only the days
    // are counted, so only that text is a plural.
    @Test
    fun onlyTheDaysLeftIsAPlural() {
        for (kind in AppAlertKind.values()) {
            assertEquals(
                    kind.name,
                    kind == AppAlertKind.SUBSCRIPTION_EXPIRING,
                    appAlertContent(kind).plural,
            )
        }
    }

    @Test
    fun theKindsThatSayANumberAreTheDaysAndThePercent() {
        assertTrue(appAlertContent(AppAlertKind.SUBSCRIPTION_EXPIRING).saysNumber)
        assertTrue(appAlertContent(AppAlertKind.TRAFFIC_LOW).saysNumber)
        assertFalse(appAlertContent(AppAlertKind.SUBSCRIPTION_FAILED).saysNumber)
        assertFalse(appAlertContent(AppAlertKind.SUBSCRIPTION_EXPIRED).saysNumber)
        assertFalse(appAlertContent(AppAlertKind.TRAFFIC_EXHAUSTED).saysNumber)
    }

    // The same kind and subscription must replace its earlier alert, so the id has to be
    // the same every time, also after the process died and came back.
    @Test
    fun theIdOfAnAlertDoesNotChange() {
        assertEquals(
                appAlertId(AppAlertKind.TRAFFIC_LOW, "Liberty VPN"),
                appAlertId(AppAlertKind.TRAFFIC_LOW, "Liberty VPN"),
        )
    }

    @Test
    fun differentKindsOrSubscriptionsDoNotShareAnId() {
        val ids =
                listOf(
                        appAlertId(AppAlertKind.TRAFFIC_LOW, "Liberty VPN"),
                        appAlertId(AppAlertKind.TRAFFIC_EXHAUSTED, "Liberty VPN"),
                        appAlertId(AppAlertKind.TRAFFIC_LOW, "DuckVPN"),
                        appAlertId(AppAlertKind.SUBSCRIPTION_FAILED, "DuckVPN"),
                )

        assertEquals(ids.size, ids.toSet().size)
    }

    // 1 is the VPN notification and 2 the connection alert (V2RayVpnService).
    @Test
    fun anIdNeverTakesTheOnesOfTheVpnService() {
        val names = listOf("", "a", "Liberty VPN", "DuckVPN", "Подписка", "x".repeat(500))
        for (kind in AppAlertKind.values()) {
            for (name in names) {
                val id = appAlertId(kind, name)
                assertTrue("$kind/$name: $id", id >= 1000)
                assertNotEquals(1, id)
                assertNotEquals(2, id)
            }
        }
    }
}
