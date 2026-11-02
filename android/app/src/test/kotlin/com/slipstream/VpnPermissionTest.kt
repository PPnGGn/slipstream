package com.slipstream

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VpnPermissionTest {

    @Test
    fun anIdleServiceMayAskTheSystem() {
        assertTrue(shouldAskPermission(VpnStatus.DISCONNECTED))
        assertTrue(shouldAskPermission(VpnStatus.ERROR))
    }

    @Test
    fun aServiceThatIsActiveNeverAsks() {
        // VpnService.prepare() unprepares this app's own VPN when it is the current
        // one: asking while it runs, or while the kill switch holds the traffic,
        // would tear the tunnel down (or open the traffic) just to ask.
        assertFalse(shouldAskPermission(VpnStatus.CONNECTING))
        assertFalse(shouldAskPermission(VpnStatus.CONNECTED))
        assertFalse(shouldAskPermission(VpnStatus.DISCONNECTING))
        assertFalse(shouldAskPermission(VpnStatus.BLOCKED))
    }
}
