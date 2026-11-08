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

    // The alert switches. On until the user says otherwise, also before the app ever
    // sent them: an alert that is off by default never reaches the person who needs it.
    fun alertTrafficBlocked(): Boolean = prefs.getBoolean(KEY_ALERT_TRAFFIC_BLOCKED, true)

    fun alertStartFailed(): Boolean = prefs.getBoolean(KEY_ALERT_START_FAILED, true)

    fun saveAlertTrafficBlocked(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_ALERT_TRAFFIC_BLOCKED, enabled).apply()
    }

    fun saveAlertStartFailed(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_ALERT_START_FAILED, enabled).apply()
    }

    companion object {
        private const val FILE = "slipstream_native_prefs"
        private const val KEY_LANGUAGE = "language"
        private const val KEY_ALERT_TRAFFIC_BLOCKED = "alert_traffic_blocked"
        private const val KEY_ALERT_START_FAILED = "alert_start_failed"

        fun of(context: Context) =
                NativePrefsStore(
                        context.applicationContext.getSharedPreferences(FILE, Context.MODE_PRIVATE),
                )
    }
}
