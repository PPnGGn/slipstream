package com.slipstream

import java.io.Closeable
import java.io.IOException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class TunnelInterfacesTest {

    // Stands for a ParcelFileDescriptor: what matters is whether it was closed.
    private class FakeInterface(val name: String, private val failOnClose: Boolean = false) :
            Closeable {
        var closes = 0

        override fun close() {
            closes++
            if (failOnClose) throw IOException("close failed")
        }
    }

    private fun holder() = TunnelInterfaces<FakeInterface>()

    // --- a session that starts ---

    @Test
    fun theInterfaceOfASessionIsKeptOpenWhileItRuns() {
        val h = holder()
        val tun = FakeInterface("tun")
        h.begin(tun)
        h.sessionUp()
        assertSame(tun, h.session)
        assertEquals(0, tun.closes)
    }

    @Test
    fun aSessionThatIsUpClosesTheBlockingInterfaceItReplaced() {
        val h = holder()
        val first = FakeInterface("first")
        val second = FakeInterface("second")
        h.begin(first)
        h.holdBlocking { error("no new interface needed") }
        // A reconnect: the second interface replaced the first, which is the block.
        h.begin(second)
        h.sessionUp()
        assertNull(h.blocking)
        assertEquals(1, first.closes)
        assertEquals(0, second.closes)
    }

    // --- a start that fails, with the kill switch ---

    @Test
    fun aFailedStartHoldsTheInterfaceItAlreadyHasWithoutClosingIt() {
        val h = holder()
        val tun = FakeInterface("tun")
        h.begin(tun)
        h.holdBlocking { error("the interface exists, none is built") }
        assertSame(tun, h.blocking)
        assertNull(h.session)
        assertEquals("the traffic must never be released in between", 0, tun.closes)
    }

    @Test
    fun aFailedStartBeforeAnyInterfaceBuildsOne() {
        val h = holder()
        val built = FakeInterface("built")
        h.holdBlocking { built }
        assertSame(built, h.blocking)
        assertNull(h.session)
    }

    @Test
    fun aFailedReconnectFromABlockReplacesTheOldBlockAndClosesIt() {
        val h = holder()
        val old = FakeInterface("old")
        h.begin(old)
        h.holdBlocking { error("unused") }
        val retry = FakeInterface("retry")
        h.begin(retry)
        h.holdBlocking { error("unused") }
        assertSame(retry, h.blocking)
        assertEquals(1, old.closes)
        assertEquals(0, retry.closes)
    }

    @Test
    fun ifNoInterfaceCanBeBuiltNothingIsChangedAndTheErrorGoesOn() {
        val h = holder()
        val old = FakeInterface("old")
        h.begin(old)
        h.holdBlocking { error("unused") }
        // A reconnect that fails before it has an interface: the old block must stay.
        try {
            h.holdBlocking { throw IllegalStateException("permission gone") }
            throw AssertionError("the error was swallowed")
        } catch (e: IllegalStateException) {
            assertEquals("permission gone", e.message)
        }
        assertSame(old, h.blocking)
        assertEquals(0, old.closes)
    }

    // --- the end of everything ---

    @Test
    fun releasingClosesTheSessionInterfaceOrThePhoneStaysWithoutNetwork() {
        val h = holder()
        val tun = FakeInterface("tun")
        h.begin(tun)
        h.sessionUp()
        h.releaseAll()
        assertEquals(1, tun.closes)
        assertNull(h.session)
        assertFalse(h.hasAny)
    }

    @Test
    fun releasingClosesTheBlockingInterfaceOnce() {
        val h = holder()
        val tun = FakeInterface("tun")
        h.begin(tun)
        h.holdBlocking { error("unused") }
        h.releaseAll()
        assertEquals(1, tun.closes)
        assertNull(h.blocking)
        h.releaseAll()
        assertEquals("a second release closes nothing again", 1, tun.closes)
    }

    @Test
    fun anInterfaceThatFailsToCloseDoesNotStopTheOthers() {
        val reported = mutableListOf<String>()
        val h = TunnelInterfaces<FakeInterface>(onCloseError = { reported += it.message ?: "" })
        val stuck = FakeInterface("stuck", failOnClose = true)
        h.begin(stuck)
        h.holdBlocking { error("unused") }
        val next = FakeInterface("next")
        h.begin(next)
        h.releaseAll()
        assertEquals(1, stuck.closes)
        assertEquals(1, next.closes)
        assertEquals(listOf("close failed"), reported)
    }

    @Test
    fun hasAnyIsTrueForASessionAndForABlock() {
        val h = holder()
        assertFalse(h.hasAny)
        h.begin(FakeInterface("tun"))
        assertTrue(h.hasAny)
        h.holdBlocking { error("unused") }
        assertTrue(h.hasAny)
    }
}
