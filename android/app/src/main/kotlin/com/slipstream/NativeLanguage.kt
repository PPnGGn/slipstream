package com.slipstream

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

// The language of the texts Kotlin shows by itself (the VPN notification, the tile).
// The user picks it in the app (Settings → Appearance); Dart sends it through
// NativePrefsApi and NativePrefsStore keeps it, so it is known here even while the
// app is closed.

private val appLanguages = setOf("en", "ru", "zh", "fa")

// The language tag for a stored code, or null for "follow the phone": the code "system",
// nothing stored, or a language this version does not have.
internal fun languageTagFor(code: String?): String? = code?.trim()?.takeIf { it in appLanguages }

// [base] with the chosen language applied; [base] itself when the phone's language rules.
// The service and the tile build every text from the result.
fun localizedContext(base: Context, code: String?): Context {
    val tag = languageTagFor(code) ?: return base
    val configuration = Configuration(base.resources.configuration)
    configuration.setLocale(Locale.forLanguageTag(tag))
    return base.createConfigurationContext(configuration)
}
