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

    private fun pluralNames(folder: String): Set<String> =
            Regex("""<plurals\s+name="([^"]+)"""")
                    .findAll(File("src/main/res/$folder/strings.xml").readText())
                    .map { it.groupValues[1] }
                    .toSet()

    private fun quantities(folder: String, name: String): Set<String> {
        val source = File("src/main/res/$folder/strings.xml").readText()
        val block =
                Regex("""<plurals\s+name="$name">(.*?)</plurals>""", RegexOption.DOT_MATCHES_ALL)
                        .find(source)!!
                        .groupValues[1]
        return Regex("""quantity="([^"]+)"""").findAll(block).map { it.groupValues[1] }.toSet()
    }

    @Test
    fun everyLanguageHasEveryPlural() {
        val english = pluralNames("values")
        assertTrue("no plurals at all", english.isNotEmpty())
        for (folder in listOf("values-ru", "values-zh", "values-fa")) {
            assertEquals(folder, english, pluralNames(folder))
        }
    }

    // A plural without the forms of its language shows the wrong word for some numbers
    // (Russian has four forms, Chinese one).
    @Test
    fun everyPluralHasTheFormsOfItsLanguage() {
        val needed =
                mapOf(
                        "values" to setOf("one", "other"),
                        "values-ru" to setOf("one", "few", "many", "other"),
                        "values-zh" to setOf("other"),
                        "values-fa" to setOf("one", "other"),
                )
        for ((folder, forms) in needed) {
            for (name in pluralNames("values")) {
                assertTrue(
                        "$folder/$name lacks a form",
                        quantities(folder, name).containsAll(forms),
                )
            }
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
