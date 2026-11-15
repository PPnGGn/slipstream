package com.slipstream

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

// Subscriptions (server keys, UUIDs, Trojan/Hysteria2 passwords) live as plain JSON in the
// app's files directory. Android Auto Backup defaults to enabled, which would upload them
// unencrypted to cloud backup or device-to-device transfer unless explicitly disabled.
class AndroidManifestSecurityTest {

    @Test
    fun autoBackupIsDisabled() {
        val manifest = File("src/main/AndroidManifest.xml")
        assertTrue("missing $manifest", manifest.exists())
        val text = manifest.readText()
        val appTag =
                Regex("""<application\b[^>]*>""", RegexOption.DOT_MATCHES_ALL)
                        .find(text)
                        ?.value
                        ?: ""
        assertTrue(
                "<application> must declare android:allowBackup=\"false\"",
                appTag.contains("""android:allowBackup="false""""),
        )
    }
}
