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
    // The tunnel died under a connected VPN (the core says so) and there is no kill
    // switch to hold the traffic: the VPN was closed, and the user has to know that
    // it is not protecting anything.
    TUNNEL_LOST,
}

// The switches of the Notifications page, as Kotlin knows them (NativePrefsStore).
data class AlertPrefs(
        val trafficBlocked: Boolean,
        val startFailed: Boolean,
        val revoked: Boolean = true,
        val tunnelLost: Boolean = true,
)

// What the service does when the core reports that the tunnel of a running session
// died (StatusHandler.OnTunnelLost): xray and the interface are up, and the traffic
// has stopped without a word.
enum class TunnelLostAction {
    // Nothing: the report is stale or not about a connected VPN.
    IGNORE,
    // The kill switch is on: hold the traffic in the blocking interface, as after a
    // failed start (holdBlockingTunnel).
    HOLD,
    // No kill switch: close the VPN with an error, so the phone is not left with a
    // "connected" VPN that carries nothing.
    CLOSE,
}

// [status]: what the service says about itself right now. The core also reports the end
// of a tunnel that we stop ourselves, from another thread and a moment after, so a
// stopping service ([stopping]) and any status but CONNECTED mean there is nothing to
// do: the tunnel of a VPN that is connecting, blocked or off is not "lost".
internal fun tunnelLostAction(
        status: VpnStatus,
        stopping: Boolean,
        killSwitch: Boolean,
): TunnelLostAction =
        when {
            stopping || status != VpnStatus.CONNECTED -> TunnelLostAction.IGNORE
            killSwitch -> TunnelLostAction.HOLD
            else -> TunnelLostAction.CLOSE
        }

// A held tunnel is blocked traffic, whatever blocked it, so it has the alert of the
// kill switch and its switch; a closed one has its own.
internal fun alertAfterTunnelLoss(action: TunnelLostAction, prefs: AlertPrefs): ConnectionAlert? =
        when (action) {
            TunnelLostAction.HOLD -> ConnectionAlert.TRAFFIC_BLOCKED.takeIf { prefs.trafficBlocked }
            TunnelLostAction.CLOSE -> ConnectionAlert.TUNNEL_LOST.takeIf { prefs.tunnelLost }
            TunnelLostAction.IGNORE -> null
        }

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
            // Reconnect: the saved launch is still good, only the tunnel is gone.
            ConnectionAlert.TUNNEL_LOST ->
                    AlertContent(
                            R.string.alert_tunnel_lost_title,
                            R.string.alert_tunnel_lost_text,
                            canReconnect = true,
                    )
        }
