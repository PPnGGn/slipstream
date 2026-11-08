package com.slipstream

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// The four string files (English default, ru, zh, fa) must name the same texts: a text
// missing in one language would silently show English there.
class NativeStringsTest {

    // Gradle runs unit tests with the module (android/app) as the working directory.
    private fun names(folder: String): Set<String> {
        val file = File("src/main/res/$folder/strings.xml")
        assertTrue("missing $file", file.exists())
        return Regex("""<string\s+name="([^"]+)"""")
                .findAll(file.readText())
                .map { it.groupValues[1] }
                .toSet()
    }

    private fun text(folder: String, name: String): String {
        val source = File("src/main/res/$folder/strings.xml").readText()
        return Regex("""<string\s+name="$name"[^>]*>([^<]*)</string>""")
                .find(source)!!
                .groupValues[1]
    }

    // app_name is the product name and is not translated.
    private val translated = names("values") - "app_name"

    @Test
    fun everyLanguageHasEveryText() {
        for (folder in listOf("values-ru", "values-zh", "values-fa")) {
            assertEquals(folder, translated, names(folder))
        }
    }

    @Test
    fun everyTextIsFilledIn() {
        for (folder in listOf("values", "values-ru", "values-zh", "values-fa")) {
            for (name in translated) {
                assertTrue("$folder/$name is empty", text(folder, name).isNotBlank())
            }
        }
    }

    @Test
    fun theTranslationsReallyDifferFromEnglish() {
        for (folder in listOf("values-ru", "values-zh", "values-fa")) {
            assertFalse(
                    "$folder repeats the English text of the notification",
                    text(folder, "notification_connected") == text("values", "notification_connected"),
            )
        }
    }
}
