package com.slipstream

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NativeLanguageTest {

    @Test
    fun theLanguagesOfTheAppAreKnown() {
        assertEquals("en", languageTagFor("en"))
        assertEquals("ru", languageTagFor("ru"))
        assertEquals("zh", languageTagFor("zh"))
        assertEquals("fa", languageTagFor("fa"))
    }

    // "system" is what the app stores for "follow the phone": the service then uses
    // the language of the system as it is.
    @Test
    fun systemMeansTheLanguageOfThePhone() {
        assertNull(languageTagFor("system"))
        assertNull(languageTagFor(null))
    }

    // A language dropped in a later version, or an empty value, must not break the
    // text: the phone's language is the safe fallback.
    @Test
    fun anUnknownCodeFallsBackToThePhone() {
        assertNull(languageTagFor("tr"))
        assertNull(languageTagFor(""))
        assertNull(languageTagFor("  "))
    }
}
