package com.slipstream.apps

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class InstalledAppRulesTest {

    @Test
    fun preinstalledAppWithoutLauncherIconIsSystem() {
        assertTrue(isHiddenSystemApp(isPreinstalled = true, hasLauncherActivity = false))
    }

    @Test
    fun preinstalledAppWithLauncherIconStaysInTheMainList() {
        assertFalse(isHiddenSystemApp(isPreinstalled = true, hasLauncherActivity = true))
    }

    @Test
    fun userInstalledAppIsNeverSystem() {
        assertFalse(isHiddenSystemApp(isPreinstalled = false, hasLauncherActivity = false))
        assertFalse(isHiddenSystemApp(isPreinstalled = false, hasLauncherActivity = true))
    }
}
