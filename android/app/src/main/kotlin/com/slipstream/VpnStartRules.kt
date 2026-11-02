package com.slipstream

// Who started the service. The service decides what to do about it with
// startDecision; both are plain functions so the rules are testable without Android.
enum class StartTrigger {
    // The app: the intent carries the whole launch.
    APP,
    // The quick settings tile, or a Reconnect button: "start the saved launch again".
    START_LAST,
    // The system itself (Always-on VPN): the intent has the VpnService action.
    SYSTEM,
    // Android restarted the service after the process died (START_STICKY): null intent.
    RESTART,
    OTHER,
}

enum class StartDecision {
    // Do nothing: a session is already up.
    IGNORE,
    START_FROM_APP,
    START_SAVED,
    NOTHING_TO_START,
}

// The action Android puts on the intent when it starts a VPN service by itself.
private const val SYSTEM_VPN_ACTION = "android.net.VpnService"

internal fun startTriggerFor(action: String?, hasConfig: Boolean): StartTrigger =
        when {
            hasConfig -> StartTrigger.APP
            action == V2RayVpnService.ACTION_START_LAST -> StartTrigger.START_LAST
            action == SYSTEM_VPN_ACTION -> StartTrigger.SYSTEM
            action == null -> StartTrigger.RESTART
            else -> StartTrigger.OTHER
        }

// What a failed start leads to: true holds the blocking interface (the kill
// switch), false closes the VPN and reports an error, as it always did.
//
// The kill switch answers a LOSS of the tunnel, not a tunnel that never came up:
//  - an unattended start (the process died and Android restarts the service, or the
//    system starts the VPN) means a tunnel was up and is gone: block;
//  - a start the user asked for, from cold (a tap on the ring, the tile) that fails
//    is a server or config that does not work, and cutting the phone off for it
//    would punish a mistake nobody could have prevented: an ordinary error;
//  - but once the traffic is blocked, a failed reconnect stays blocked, because
//    closing the blocking interface would open the traffic.
internal fun shouldBlockOnFailure(
        killSwitch: Boolean,
        trigger: StartTrigger,
        alreadyBlocked: Boolean,
): Boolean =
        killSwitch &&
                (alreadyBlocked || trigger == StartTrigger.RESTART || trigger == StartTrigger.SYSTEM)

// savedKillSwitch: the kill switch of the saved launch, null when nothing is saved.
// startInterrupted: the last start never finished (the process died while starting),
// so starting by ourselves again could be a crash loop. Only starts nobody asked
// for are held back by it: a tap on the tile or a new start from the app go through.
internal fun startDecision(
        trigger: StartTrigger,
        sessionRunning: Boolean,
        savedKillSwitch: Boolean?,
        startInterrupted: Boolean,
): StartDecision {
    // The core refuses a second Start while one runs, and the refusal would take the
    // whole VPN down: a duplicate start must change nothing.
    if (sessionRunning) return StartDecision.IGNORE
    return when (trigger) {
        StartTrigger.APP -> StartDecision.START_FROM_APP
        StartTrigger.START_LAST ->
                if (savedKillSwitch != null) StartDecision.START_SAVED
                else StartDecision.NOTHING_TO_START
        StartTrigger.SYSTEM ->
                if (savedKillSwitch != null && !startInterrupted) StartDecision.START_SAVED
                else StartDecision.NOTHING_TO_START
        // Without the kill switch a dead process just means a disconnected VPN, as before.
        StartTrigger.RESTART ->
                if (savedKillSwitch == true && !startInterrupted) StartDecision.START_SAVED
                else StartDecision.NOTHING_TO_START
        StartTrigger.OTHER -> StartDecision.NOTHING_TO_START
    }
}
