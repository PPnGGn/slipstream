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
    // Another VPN app took over (onRevoke) while ours was up: the user did not switch
    // it off, and the traffic now goes unprotected.
    REVOKED,
}

// The switches of the Notifications page, as Kotlin knows them (NativePrefsStore).
data class AlertPrefs(
        val trafficBlocked: Boolean,
        val startFailed: Boolean,
        val revoked: Boolean = true,
)

// What a revoke leads to. [statusBefore] is the status the service had when the system
// called onRevoke: only a VPN that was up (or coming up, or holding the traffic) was
// taken from the user. onRevoke is also called when our own VpnService.prepare() runs
// and when the user switches us off; the status is DISCONNECTED or DISCONNECTING then.
internal fun alertOnRevoke(statusBefore: VpnStatus, prefs: AlertPrefs): ConnectionAlert? =
        when (statusBefore) {
            VpnStatus.CONNECTED, VpnStatus.CONNECTING, VpnStatus.BLOCKED ->
                    ConnectionAlert.REVOKED.takeIf { prefs.revoked }
            VpnStatus.DISCONNECTED, VpnStatus.DISCONNECTING, VpnStatus.ERROR -> null
        }

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
            // No Reconnect: it would call VpnService.prepare(), which takes the VPN from
            // the other app through a system dialog. The alert opens the app instead.
            ConnectionAlert.REVOKED ->
                    AlertContent(
                            R.string.alert_revoked_title,
                            R.string.alert_revoked_text,
                            canReconnect = false,
                    )
        }
