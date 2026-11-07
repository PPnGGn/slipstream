package com.slipstream

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

// The launch the app saves for the tile (saveLaunch) must be the one a start from the
// app would have produced: same fields, same defaults. startVpnService (the intent) and
// launchFromIntent in the service are the other half of that; this pins the message half.
class VpnLaunchFromMessageTest {

    @get:Rule val folder = TemporaryFolder()

    private fun message(
            configJson: String = """{"a":1}""",
            title: String? = "Amsterdam",
            geoAssetDir: String? = "/geo",
            hijackDns: Boolean? = true,
            splitMode: VpnSplitMode? = null,
            splitPackages: List<String>? = null,
            ipv6: Boolean? = null,
            killSwitch: Boolean? = null,
    ) =
            VpnConfigMessage(
                    configJson = configJson,
                    serverId = "s1",
                    title = title,
                    geoAssetDir = geoAssetDir,
                    hijackDns = hijackDns,
                    splitMode = splitMode,
                    splitPackages = splitPackages,
                    ipv6 = ipv6,
                    killSwitch = killSwitch,
            )

    @Test
    fun everyFieldIsCarriedOver() {
        val launch =
                message(
                                splitMode = VpnSplitMode.BYPASS,
                                splitPackages = listOf("com.a", "com.b"),
                                ipv6 = true,
                                killSwitch = true,
                        )
                        .toLaunch("/default-geo")

        assertEquals("""{"a":1}""", launch.configJson)
        assertEquals("/geo", launch.geoDir)
        assertTrue(launch.hijackDns)
        assertEquals(VpnSplitMode.BYPASS, launch.splitMode)
        assertEquals(listOf("com.a", "com.b"), launch.splitPackages)
        assertEquals("Amsterdam", launch.serverTitle)
        assertTrue(launch.ipv6)
        assertTrue(launch.killSwitch)
    }

    @Test
    fun noGeoDirectoryFallsBackToTheDefaultOne() {
        assertEquals("/default-geo", message(geoAssetDir = null).toLaunch("/default-geo").geoDir)
    }

    @Test
    fun nullSwitchesCountAsOffLikeInTheIntent() {
        // A message from an older Dart build carries no ipv6 / killSwitch / hijackDns.
        val launch = message(hijackDns = null, ipv6 = null, killSwitch = null).toLaunch("/g")

        assertFalse(launch.hijackDns)
        assertFalse(launch.ipv6)
        assertFalse(launch.killSwitch)
    }

    @Test
    fun aSplitModeNeedsPackagesAndPackagesNeedAMode() {
        // Both or neither, as startVpnService does: the service reads a missing mode as
        // "no split", so half a split must not be saved as one.
        val modeOnly = message(splitMode = VpnSplitMode.PROXY, splitPackages = emptyList()).toLaunch("/g")
        val modeNull = message(splitMode = VpnSplitMode.PROXY, splitPackages = null).toLaunch("/g")
        val packagesOnly = message(splitMode = null, splitPackages = listOf("com.a")).toLaunch("/g")

        for (launch in listOf(modeOnly, modeNull, packagesOnly)) {
            assertNull(launch.splitMode)
            assertEquals(emptyList<String>(), launch.splitPackages)
        }
    }

    @Test
    fun noTitleStaysNull() {
        assertNull(message(title = null).toLaunch("/g").serverTitle)
    }

    @Test
    fun whatIsSavedIsWhatTheTileLoads() {
        val store = VpnLaunchStore(folder.root)
        val launch = message(splitMode = VpnSplitMode.PROXY, splitPackages = listOf("com.a")).toLaunch("/g")

        store.save(launch)

        assertEquals(launch, store.load())
    }
}
