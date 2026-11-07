package com.slipstream

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VpnLaunchSaveTest {

    @Test
    fun anIdleServiceTakesANewSavedLaunch() {
        assertTrue(shouldSaveLaunch(VpnStatus.DISCONNECTED))
        assertTrue(shouldSaveLaunch(VpnStatus.ERROR))
    }

    @Test
    fun aServiceThatIsActiveKeepsItsLaunch() {
        // A restart of the service after the process died, and Reconnect from the kill
        // switch's hold, read the saved launch: replacing it under a live session would
        // bring back a different server than the one that was up. The Dart side checks
        // too; this is the native end of the same rule.
        assertFalse(shouldSaveLaunch(VpnStatus.CONNECTING))
        assertFalse(shouldSaveLaunch(VpnStatus.CONNECTED))
        assertFalse(shouldSaveLaunch(VpnStatus.DISCONNECTING))
        assertFalse(shouldSaveLaunch(VpnStatus.BLOCKED))
    }
}
