package com.slipstream

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SplitTunnelRulesTest {

    private val own = "com.slipstream"

    private class Builder(private val installed: Set<String>) {
        val allowed = mutableListOf<String>()
        val disallowed = mutableListOf<String>()

        fun allow(pkg: String): Boolean = (pkg in installed).also { if (it) allowed.add(pkg) }

        fun disallow(pkg: String): Boolean =
                (pkg in installed).also { if (it) disallowed.add(pkg) }
    }

    private fun apply(
            mode: VpnSplitMode?,
            packages: List<String>,
            installed: Set<String>,
    ): Pair<Builder, SplitTunnelOutcome> {
        val builder = Builder(installed + own)
        val outcome = applySplitTunnel(mode, packages, own, builder::allow, builder::disallow)
        return builder to outcome
    }

    @Test
    fun noModeKeepsOnlyOurselfOutOfTheTunnel() {
        val (builder, outcome) = apply(null, listOf("a"), setOf("a"))
        assertEquals(listOf(own), builder.disallowed)
        assertTrue(builder.allowed.isEmpty())
        assertFalse(outcome.fellBackToFullTunnel)
    }

    @Test
    fun anEmptyListCountsAsOff() {
        val (builder, _) = apply(VpnSplitMode.PROXY, emptyList(), emptySet())
        assertEquals(listOf(own), builder.disallowed)
        assertTrue(builder.allowed.isEmpty())
    }

    @Test
    fun bypassExcludesOurselfAndEveryPickedApp() {
        val (builder, outcome) = apply(VpnSplitMode.BYPASS, listOf("a", "b"), setOf("a", "b"))
        assertEquals(listOf(own, "a", "b"), builder.disallowed)
        assertEquals(2, outcome.applied)
        assertEquals(0, outcome.skipped)
    }

    @Test
    fun bypassNeverAllows() {
        val (builder, _) = apply(VpnSplitMode.BYPASS, listOf("a"), setOf("a"))
        assertTrue(builder.allowed.isEmpty())
    }

    @Test
    fun bypassSkipsAnUninstalledApp() {
        val (builder, outcome) = apply(VpnSplitMode.BYPASS, listOf("gone", "a"), setOf("a"))
        assertEquals(listOf(own, "a"), builder.disallowed)
        assertEquals(1, outcome.applied)
        assertEquals(1, outcome.skipped)
    }

    @Test
    fun bypassDoesNotListOurselfTwice() {
        val (builder, _) = apply(VpnSplitMode.BYPASS, listOf(own, "a"), setOf("a"))
        assertEquals(listOf(own, "a"), builder.disallowed)
    }

    @Test
    fun proxyAllowsEveryPickedApp() {
        val (builder, outcome) = apply(VpnSplitMode.PROXY, listOf("a", "b"), setOf("a", "b"))
        assertEquals(listOf("a", "b"), builder.allowed)
        assertEquals(2, outcome.applied)
        assertFalse(outcome.fellBackToFullTunnel)
    }

    @Test
    fun proxyNeverMixesInADisallowedApp() {
        val (builder, _) = apply(VpnSplitMode.PROXY, listOf("a"), setOf("a"))
        assertTrue(builder.disallowed.isEmpty())
    }

    @Test
    fun proxyNeverAllowsOurself() {
        val (builder, _) = apply(VpnSplitMode.PROXY, listOf(own, "a"), setOf("a"))
        assertEquals(listOf("a"), builder.allowed)
    }

    @Test
    fun proxySkipsAnUninstalledApp() {
        val (builder, outcome) = apply(VpnSplitMode.PROXY, listOf("gone", "a"), setOf("a"))
        assertEquals(listOf("a"), builder.allowed)
        assertEquals(1, outcome.skipped)
    }

    @Test
    fun proxyWithEveryPickedAppGoneFallsBackToTheFullTunnel() {
        val (builder, outcome) = apply(VpnSplitMode.PROXY, listOf("gone", "also-gone"), emptySet())
        assertTrue(builder.allowed.isEmpty())
        assertEquals(listOf(own), builder.disallowed)
        assertTrue(outcome.fellBackToFullTunnel)
        assertEquals(0, outcome.applied)
        assertEquals(2, outcome.skipped)
    }

    @Test
    fun proxyWithOnlyOurselfPickedFallsBackToTheFullTunnel() {
        val (builder, outcome) = apply(VpnSplitMode.PROXY, listOf(own), emptySet())
        assertTrue(builder.allowed.isEmpty())
        assertEquals(listOf(own), builder.disallowed)
        assertTrue(outcome.fellBackToFullTunnel)
    }
}
