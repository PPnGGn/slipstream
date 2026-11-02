package com.slipstream

import org.junit.Assert.assertEquals
import org.junit.Test

class VpnStartRulesTest {

    // --- startTriggerFor: what started the service ---

    @Test
    fun aConfigInTheIntentIsAnAppStartWhateverTheAction() {
        assertEquals(StartTrigger.APP, startTriggerFor(action = null, hasConfig = true))
        assertEquals(StartTrigger.APP, startTriggerFor(action = "x", hasConfig = true))
    }

    @Test
    fun theTilesActionIsStartLast() {
        assertEquals(
                StartTrigger.START_LAST,
                startTriggerFor(V2RayVpnService.ACTION_START_LAST, hasConfig = false),
        )
    }

    @Test
    fun theSystemsVpnActionIsASystemStart() {
        assertEquals(
                StartTrigger.SYSTEM,
                startTriggerFor("android.net.VpnService", hasConfig = false),
        )
    }

    @Test
    fun noActionAndNoConfigIsARestartAfterTheProcessDied() {
        assertEquals(StartTrigger.RESTART, startTriggerFor(action = null, hasConfig = false))
    }

    @Test
    fun anyOtherActionIsNotAStart() {
        assertEquals(StartTrigger.OTHER, startTriggerFor("something.else", hasConfig = false))
    }

    // --- startDecision: what to do about it ---

    private fun decide(
            trigger: StartTrigger,
            running: Boolean = false,
            savedKillSwitch: Boolean? = null,
            interrupted: Boolean = false,
    ) = startDecision(trigger, running, savedKillSwitch, interrupted)

    @Test
    fun aRunningSessionIgnoresEveryStart() {
        // The core refuses a second Start; without this the refusal would tear the VPN down.
        for (trigger in StartTrigger.values()) {
            assertEquals(
                    StartDecision.IGNORE,
                    decide(trigger, running = true, savedKillSwitch = true),
            )
        }
    }

    @Test
    fun anAppStartUsesTheIntentNotTheSavedLaunch() {
        assertEquals(StartDecision.START_FROM_APP, decide(StartTrigger.APP))
        assertEquals(
                StartDecision.START_FROM_APP,
                decide(StartTrigger.APP, savedKillSwitch = false, interrupted = true),
        )
    }

    @Test
    fun theTilesStartTakesTheSavedLaunchEvenAfterAnInterruptedStart() {
        // A tap is the user's own act: the crash-loop guard does not apply.
        assertEquals(
                StartDecision.START_SAVED,
                decide(StartTrigger.START_LAST, savedKillSwitch = false, interrupted = true),
        )
    }

    @Test
    fun theTilesStartWithNothingSavedHasNothingToStart() {
        assertEquals(StartDecision.NOTHING_TO_START, decide(StartTrigger.START_LAST))
    }

    @Test
    fun aSystemStartTakesTheSavedLaunchWhateverTheKillSwitch() {
        assertEquals(
                StartDecision.START_SAVED,
                decide(StartTrigger.SYSTEM, savedKillSwitch = false),
        )
        assertEquals(
                StartDecision.START_SAVED,
                decide(StartTrigger.SYSTEM, savedKillSwitch = true),
        )
    }

    @Test
    fun aSystemStartAfterAnInterruptedStartOrWithNothingSavedStartsNothing() {
        assertEquals(
                StartDecision.NOTHING_TO_START,
                decide(StartTrigger.SYSTEM, savedKillSwitch = true, interrupted = true),
        )
        assertEquals(StartDecision.NOTHING_TO_START, decide(StartTrigger.SYSTEM))
    }

    @Test
    fun aRestartBringsTheTunnelBackOnlyWithTheKillSwitchOn() {
        assertEquals(
                StartDecision.START_SAVED,
                decide(StartTrigger.RESTART, savedKillSwitch = true),
        )
        assertEquals(
                StartDecision.NOTHING_TO_START,
                decide(StartTrigger.RESTART, savedKillSwitch = false),
        )
        assertEquals(StartDecision.NOTHING_TO_START, decide(StartTrigger.RESTART))
    }

    @Test
    fun aRestartAfterAnInterruptedStartDoesNotLoop() {
        // The process died while starting: starting again by ourselves could crash it again.
        assertEquals(
                StartDecision.NOTHING_TO_START,
                decide(StartTrigger.RESTART, savedKillSwitch = true, interrupted = true),
        )
    }

    @Test
    fun anUnknownTriggerStartsNothing() {
        assertEquals(
                StartDecision.NOTHING_TO_START,
                decide(StartTrigger.OTHER, savedKillSwitch = true),
        )
    }
}
