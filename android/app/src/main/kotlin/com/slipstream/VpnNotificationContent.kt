package com.slipstream

// Where the service is, as far as the notification cares.
enum class NotificationPhase {
    CONNECTING,
    CONNECTED,
    // The kill switch holds a blocking interface: no traffic gets out.
    BLOCKED,
}

// canReconnect: the notification carries a "Reconnect" button next to "Disconnect".
data class NotificationContent(val title: String, val text: String, val canReconnect: Boolean)

internal fun notificationContent(phase: NotificationPhase, serverTitle: String?): NotificationContent =
        NotificationContent(
                title = serverTitle?.trim()?.takeIf { it.isNotEmpty() } ?: "Slipstream",
                text =
                        when (phase) {
                            NotificationPhase.CONNECTING -> "Connecting…"
                            NotificationPhase.CONNECTED -> "Connected"
                            NotificationPhase.BLOCKED -> "Connection lost · traffic blocked"
                        },
                canReconnect = phase == NotificationPhase.BLOCKED,
        )
