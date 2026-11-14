package com.slipstream

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build

// The notification channel and the "open the app" tap that every alert shares: the
// connection alerts of the VPN service and the subscription alerts of AppAlerts. One
// channel, so the user turns all of them on or off in one place of the system settings.
object AlertChannel {
    const val ID = "slipstream_alerts"

    // Created on every use, not only the first: creating a channel that exists changes its
    // name (what the user sees in the system settings, so it follows the chosen language)
    // and leaves its importance alone. The importance is fixed at HIGH from the first
    // creation: only the user can lower it afterwards, which is why it must not start low.
    fun ensure(context: Context, name: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannel(
                NotificationChannel(ID, name, NotificationManager.IMPORTANCE_HIGH),
        )
    }

    // A tap on a notification opens the app. Null when the system has no launcher intent.
    fun openApp(context: Context): PendingIntent? {
        val launchIntent =
                context.packageManager.getLaunchIntentForPackage(context.packageName)
                        ?: return null
        return PendingIntent.getActivity(
                context,
                1,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
