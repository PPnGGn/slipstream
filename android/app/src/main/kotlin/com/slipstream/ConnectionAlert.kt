package com.slipstream

import androidx.annotation.StringRes

// The alerts the VPN service raises on its own, when nobody may be looking at the app:
// a separate, noticeable notification next to the quiet foreground one. Decided by plain
// functions, so the rules can be tested without Android; V2RayVpnService only posts what
// they say.

enum class ConnectionAlert {
    // The kill switch holds the traffic: the tunnel is gone and nothing gets out.
    TRAFFIC_BLOCKED,
    // The VPN could not start without the app (the tile, Always-on VPN, a restart).
    START_FAILED,
}

// The two switches of the Notifications page, as Kotlin knows them (NativePrefsStore).
data class AlertPrefs(val trafficBlocked: Boolean, val startFailed: Boolean)

// What a failed start leads to. [blocked]: the kill switch is holding the traffic (see
// shouldBlockOnFailure); otherwise the VPN is closed with an error.
//
// A start made in the app does not alert about an error: the main screen shows it. Held
// traffic always does, whoever started the attempt, because the app may be in the
// background by then.
internal fun alertAfterFailure(
        blocked: Boolean,
        trigger: StartTrigger,
        prefs: AlertPrefs,
): ConnectionAlert? =
        when {
            blocked -> ConnectionAlert.TRAFFIC_BLOCKED.takeIf { prefs.trafficBlocked }
            trigger == StartTrigger.APP -> null
            else -> ConnectionAlert.START_FAILED.takeIf { prefs.startFailed }
        }

// What the alert says, as string resources the service resolves in the user's language.
// [canReconnect]: it carries a "Reconnect" button.
data class AlertContent(
        @StringRes val title: Int,
        @StringRes val text: Int,
        val canReconnect: Boolean,
)

internal fun alertContent(alert: ConnectionAlert): AlertContent =
        when (alert) {
            ConnectionAlert.TRAFFIC_BLOCKED ->
                    AlertContent(
                            R.string.alert_blocked_title,
                            R.string.alert_blocked_text,
                            canReconnect = true,
                    )
            ConnectionAlert.START_FAILED ->
                    AlertContent(
                            R.string.alert_start_failed_title,
                            R.string.alert_start_failed_text,
                            canReconnect = false,
                    )
        }
