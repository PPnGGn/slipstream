package com.slipstream.alerts

import android.app.NotificationManager
import android.content.Context
import android.util.Log
import androidx.annotation.StringRes
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.slipstream.AlertChannel
import com.slipstream.R
import com.slipstream.localizedContext
import com.slipstream.nativeprefs.NativePrefsStore

// What the alert says, as string resources: the title, and the text that takes the name of
// the subscription as %1$s and, when [saysNumber], the days or the percent as %2$d.
// [plural]: the text is a plurals resource (the days left), picked by that number.
internal data class AppAlertContent(
        @StringRes val title: Int,
        @StringRes val text: Int,
        val plural: Boolean,
        val saysNumber: Boolean,
)

internal fun appAlertContent(kind: AppAlertKind): AppAlertContent =
        when (kind) {
            AppAlertKind.SUBSCRIPTION_FAILED ->
                    AppAlertContent(
                            R.string.alert_sub_failed_title,
                            R.string.alert_sub_failed_text,
                            plural = false,
                            saysNumber = false,
                    )
            AppAlertKind.SUBSCRIPTION_EXPIRING ->
                    AppAlertContent(
                            R.string.alert_sub_expiring_title,
                            R.plurals.alert_sub_expiring_text,
                            plural = true,
                            saysNumber = true,
                    )
            AppAlertKind.SUBSCRIPTION_EXPIRED ->
                    AppAlertContent(
                            R.string.alert_sub_expired_title,
                            R.string.alert_sub_expired_text,
                            plural = false,
                            saysNumber = false,
                    )
            AppAlertKind.TRAFFIC_LOW ->
                    AppAlertContent(
                            R.string.alert_traffic_low_title,
                            R.string.alert_traffic_low_text,
                            plural = false,
                            saysNumber = true,
                    )
            AppAlertKind.TRAFFIC_EXHAUSTED ->
                    AppAlertContent(
                            R.string.alert_traffic_exhausted_title,
                            R.string.alert_traffic_exhausted_text,
                            plural = false,
                            saysNumber = false,
                    )
        }

// The id the alert is posted under: the same for the same kind and subscription, so a new
// alert replaces the old one and [AppAlerts.cancel] finds it, also after the process died.
// From 1000 up: 1 is the VPN notification and 2 the connection alert (V2RayVpnService).
internal fun appAlertId(kind: AppAlertKind, subscriptionName: String): Int =
        1000 + ("${kind.name}:$subscriptionName".hashCode() and Int.MAX_VALUE) % 1_000_000

// Dart -> Kotlin: shows and takes away the alerts about subscriptions. Registered in the
// UI engine and in the headless engine of the background job (SubscriptionSyncWorker),
// which is where "the subscription did not update" is noticed with no app on screen.
class AppAlerts(private val context: Context) : AppAlertsApi {

    override fun show(message: AppAlertMessage) {
        // Android 13+ without the permission, or the user turned the app's notifications
        // off: nothing would show, and there is nothing to report to Dart either.
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return

        // The language the user picked, known with the app closed (NativePrefsStore).
        val texts = localizedContext(context, NativePrefsStore.of(context).language())
        AlertChannel.ensure(context, texts.getString(R.string.alert_channel_name))

        val content = appAlertContent(message.kind)
        val name = message.subscriptionName
        val number = (message.number ?: 0).toInt()
        val text =
                if (content.plural) {
                    texts.resources.getQuantityString(content.text, number, name, number)
                } else {
                    texts.getString(content.text, name, number)
                }
        val notification =
                NotificationCompat.Builder(context, AlertChannel.ID)
                        .setContentTitle(texts.getString(content.title))
                        .setContentText(text)
                        .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                        .setSmallIcon(R.mipmap.ic_launcher)
                        .setContentIntent(AlertChannel.openApp(context))
                        .setAutoCancel(true)
                        .setCategory(NotificationCompat.CATEGORY_STATUS)
                        .setPriority(NotificationCompat.PRIORITY_HIGH)
                        .build()
        try {
            context.getSystemService(NotificationManager::class.java)
                    ?.notify(appAlertId(message.kind, name), notification)
        } catch (e: SecurityException) {
            Log.w("APP_ALERTS", "Alert refused: ${e.javaClass.simpleName}")
        }
    }

    override fun cancel(kind: AppAlertKind, subscriptionName: String) {
        context.getSystemService(NotificationManager::class.java)
                ?.cancel(appAlertId(kind, subscriptionName))
    }
}
