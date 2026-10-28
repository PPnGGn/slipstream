package com.slipstream

data class NotificationContent(val title: String, val text: String)

internal fun notificationContent(connected: Boolean, serverTitle: String?): NotificationContent =
        NotificationContent(
                title = serverTitle?.trim()?.takeIf { it.isNotEmpty() } ?: "Slipstream",
                text = if (connected) "Connected" else "Connecting…",
        )
