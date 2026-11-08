package com.slipstream.nativeprefs

import android.content.Context
import android.content.SharedPreferences

// The settings the app sends to Kotlin (NativePrefsApi), kept on disk because the
// service and the tile run when the app is closed. Plain SharedPreferences: nothing
// secret in here, a language and switches.
class NativePrefsStore(private val prefs: SharedPreferences) {

    // The stored language code: 'en', 'ru', 'zh', 'fa' or 'system'; null before the app
    // ever sent one (the phone's language is used then).
    fun language(): String? = prefs.getString(KEY_LANGUAGE, null)

    fun saveLanguage(code: String) {
        prefs.edit().putString(KEY_LANGUAGE, code).apply()
    }

    companion object {
        private const val FILE = "slipstream_native_prefs"
        private const val KEY_LANGUAGE = "language"

        fun of(context: Context) =
                NativePrefsStore(
                        context.applicationContext.getSharedPreferences(FILE, Context.MODE_PRIVATE),
                )
    }
}
