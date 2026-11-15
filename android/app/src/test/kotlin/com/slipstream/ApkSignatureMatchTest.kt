package com.slipstream

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ApkSignatureMatchTest {

    @Test
    fun matchingSignersAreAccepted() {
        assertTrue(signaturesMatch(setOf("abc123"), setOf("abc123")))
        assertTrue(signaturesMatch(setOf("abc123", "def456"), setOf("def456")))
    }

    @Test
    fun mismatchingSignersAreRejected() {
        assertFalse(signaturesMatch(setOf("abc123"), setOf("def456")))
    }

    @Test
    fun missingSignersFailClosed() {
        assertFalse(signaturesMatch(emptySet(), setOf("abc123")))
        assertFalse(signaturesMatch(setOf("abc123"), emptySet()))
        assertFalse(signaturesMatch(emptySet(), emptySet()))
    }
}
