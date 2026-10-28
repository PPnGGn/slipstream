package com.slipstream

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class VpnLaunchConfigTest {

    private val full =
            VpnLaunchConfig(
                    configJson = """{"outbounds":[{"tag":"proxy"}]}""",
                    geoDir = "/data/user/0/com.slipstream/files/geo",
                    hijackDns = true,
                    splitMode = VpnSplitMode.BYPASS,
                    splitPackages = listOf("org.telegram.messenger", "com.android.chrome"),
                    serverTitle = "🇩🇪 Germany",
            )

    @Test
    fun aFullLaunchSurvivesTheRoundTrip() {
        assertEquals(full, VpnLaunchConfig.fromJson(full.toJson()))
    }

    @Test
    fun aLaunchWithoutOptionalPartsSurvivesTheRoundTrip() {
        val plain =
                VpnLaunchConfig(
                        configJson = "{}",
                        geoDir = "/geo",
                        hijackDns = false,
                        splitMode = null,
                        splitPackages = emptyList(),
                        serverTitle = null,
                )

        assertEquals(plain, VpnLaunchConfig.fromJson(plain.toJson()))
    }

    @Test
    fun theConfigIsKeptByteForByte() {
        // The config is JSON inside JSON: quotes and unicode must not change.
        val tricky = full.copy(configJson = """{"a":"q\"uote","b":"Ж ✓","c":[1,2]}""")

        assertEquals(tricky.configJson, VpnLaunchConfig.fromJson(tricky.toJson())!!.configJson)
    }

    @Test
    fun brokenJsonIsNoLaunch() {
        assertNull(VpnLaunchConfig.fromJson(""))
        assertNull(VpnLaunchConfig.fromJson("not json"))
        assertNull(VpnLaunchConfig.fromJson("[1,2]"))
        assertNull(VpnLaunchConfig.fromJson("""{"geoDir":"/geo"}"""))
        assertNull(VpnLaunchConfig.fromJson("""{"configJson":"{}"}"""))
    }

    @Test
    fun anEmptyConfigIsNoLaunch() {
        assertNull(VpnLaunchConfig.fromJson("""{"configJson":"","geoDir":"/geo"}"""))
    }

    @Test
    fun anUnknownSplitModeMeansNoSplit() {
        val launch =
                VpnLaunchConfig.fromJson(
                        """{"configJson":"{}","geoDir":"/geo","splitMode":"FUTURE","splitPackages":["a"]}""",
                )

        assertNotNull(launch)
        assertNull(launch!!.splitMode)
    }

    @Test
    fun missingOptionalFieldsTakeTheirDefaults() {
        val launch = VpnLaunchConfig.fromJson("""{"configJson":"{}","geoDir":"/geo"}""")!!

        assertFalse(launch.hijackDns)
        assertNull(launch.splitMode)
        assertTrue(launch.splitPackages.isEmpty())
        assertNull(launch.serverTitle)
    }
}
