package com.slipstream.nativeprefs

import android.content.Context
import android.content.Intent
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat

// Dart -> Kotlin: the app tells which language and which switches the service and the
// tile must use. A field that is null was not sent and stays as it was.
class NativePrefsApiImpl(
        private val context: Context,
        private val store: NativePrefsStore,
) : NativePrefsApi {

    override fun save(prefs: NativePrefsMessage) {
        prefs.language?.let { store.saveLanguage(it) }
        prefs.alertTrafficBlocked?.let { store.saveAlertTrafficBlocked(it) }
        prefs.alertStartFailed?.let { store.saveAlertStartFailed(it) }
    }

    // False when the permission (Android 13+) was refused or the user turned the app's
    // notifications off in the system settings: nothing the service posts would show.
    override fun notificationsAllowed(): Boolean =
            NotificationManagerCompat.from(context).areNotificationsEnabled()

    // The app's page in the system's notification settings. Started from the
    // application context, hence the new-task flag.
    override fun openNotificationSettings() {
        val intent =
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }
}
