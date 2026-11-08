package com.slipstream

import androidx.annotation.StringRes

// Where the service is, as far as the notification cares.
enum class NotificationPhase {
    CONNECTING,
    CONNECTED,
    // The kill switch holds a blocking interface: no traffic gets out.
    BLOCKED,
}

// What the notification says. [title] is the server name, null when there is none (the
// service then puts the app name there); [text] is a string resource, resolved by the
// service in the language the user picked. canReconnect: the notification carries a
// "Reconnect" button next to "Disconnect".
data class NotificationContent(
        val title: String?,
        @StringRes val text: Int,
        val canReconnect: Boolean,
)

internal fun notificationContent(phase: NotificationPhase, serverTitle: String?): NotificationContent =
        NotificationContent(
                title = serverTitle?.trim()?.takeIf { it.isNotEmpty() },
                text =
                        when (phase) {
                            NotificationPhase.CONNECTING -> R.string.notification_connecting
                            NotificationPhase.CONNECTED -> R.string.notification_connected
                            NotificationPhase.BLOCKED -> R.string.notification_blocked
                        },
                canReconnect = phase == NotificationPhase.BLOCKED,
        )
