package com.slipstream

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class VpnLaunchStoreTest {

    @get:Rule val folder = TemporaryFolder()

    private fun launch(config: String = "{}") =
            VpnLaunchConfig(config, "/geo", false, null, emptyList(), "Germany")

    @Test
    fun nothingSavedMeansNoLaunch() {
        val store = VpnLaunchStore(folder.root)

        assertNull(store.load())
        assertFalse(store.exists())
    }

    @Test
    fun whatWasSavedComesBack() {
        val store = VpnLaunchStore(folder.root)

        store.save(launch("""{"a":1}"""))

        assertEquals(launch("""{"a":1}"""), store.load())
        assertTrue(store.exists())
    }

    @Test
    fun aNewSaveReplacesTheOldOne() {
        val store = VpnLaunchStore(folder.root)

        store.save(launch("""{"a":1}"""))
        store.save(launch("""{"a":2}"""))

        assertEquals("""{"a":2}""", store.load()!!.configJson)
    }

    @Test
    fun aSecondStoreOnTheSameFolderSeesIt() {
        // The service and the tile are not one object: only the file joins them.
        VpnLaunchStore(folder.root).save(launch())

        assertEquals(launch(), VpnLaunchStore(folder.root).load())
    }

    @Test
    fun aBrokenFileIsNoLaunch() {
        File(folder.root, "vpn_launch.json").writeText("{ half a file")

        val store = VpnLaunchStore(folder.root)

        assertNull(store.load())
        assertFalse(store.exists())
    }

    @Test
    fun anUnfinishedWriteDoesNotHideTheLastGoodOne() {
        val store = VpnLaunchStore(folder.root)
        store.save(launch("""{"a":1}"""))
        // What a crash in the middle of a save leaves behind.
        File(folder.root, "vpn_launch.json.tmp").writeText("{ half")

        assertEquals("""{"a":1}""", store.load()!!.configJson)
    }

    @Test
    fun noTemporaryFileIsLeftAfterASave() {
        VpnLaunchStore(folder.root).save(launch())

        assertEquals(listOf("vpn_launch.json"), folder.root.list()!!.toList())
    }

    @Test
    fun clearRemovesTheLaunch() {
        val store = VpnLaunchStore(folder.root)
        store.save(launch())

        store.clear()

        assertNull(store.load())
    }

    @Test
    fun theFolderIsCreatedWhenMissing() {
        val store = VpnLaunchStore(File(folder.root, "nested/dir"))

        store.save(launch())

        assertEquals(launch(), store.load())
    }
}
