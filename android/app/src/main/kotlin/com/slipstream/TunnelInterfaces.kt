package com.slipstream

import java.io.Closeable

// The VPN interfaces the service keeps open, and who closes them. A plain class over
// Closeable (a ParcelFileDescriptor in the service) so the rules are testable without
// Android.
//
// The rule that matters: while any file descriptor of an interface is open, Android
// keeps the interface, and when the last one closes, the apps' traffic flows out
// directly, around the VPN. So the interface of a session is never closed on the way
// to being a block; only releaseAll closes what is held.
//
// The core runs on a duplicate of the descriptor (see setupVpn). When it closes that
// one after a failed start, the original stays here, and with the kill switch it
// simply becomes the blocking interface: there is no moment without an interface.
internal class TunnelInterfaces<T : Closeable>(
        private val onCloseError: (Exception) -> Unit = {},
) {
    // The interface of the session being started or running. Non-null from the moment
    // it is built until the session ends: that is what "a session is running" means
    // (see startDecision).
    var session: T? = null
        private set

    // The kill switch's hold after a failed start: an interface with the tunnel's
    // addresses and routes that nobody reads from, so whatever apps send into it goes
    // nowhere. Replaced by the real interface on Reconnect, closed on Disconnect.
    var blocking: T? = null
        private set

    val hasAny: Boolean
        get() = session != null || blocking != null

    // A session starts on this interface.
    fun begin(tunnel: T) {
        session = tunnel
    }

    // The session is up: the real interface replaced the blocking one when it was
    // established, so what is left of the block is a stale handle.
    fun sessionUp() {
        closeQuietly(blocking)
        blocking = null
    }

    // The start failed and the traffic must be held. The interface the session
    // already has becomes the block, never closed on the way; if it has none (the
    // start failed before one was built), buildNew makes one. If buildNew throws,
    // nothing here changes and the exception goes on, so the caller can fall back to
    // closing the VPN with whatever is held still tracked.
    fun holdBlocking(buildNew: () -> T) {
        val next = session ?: buildNew()
        val previous = blocking
        blocking = next
        session = null
        if (previous !== next) closeQuietly(previous)
    }

    // Everything goes: the user turned the VPN off, or it failed with nothing left to
    // hold. Safe to call twice.
    fun releaseAll() {
        val s = session
        val b = blocking
        session = null
        blocking = null
        closeQuietly(s)
        if (b !== s) closeQuietly(b)
    }

    private fun closeQuietly(tunnel: T?) {
        try {
            tunnel?.close()
        } catch (e: Exception) {
            onCloseError(e)
        }
    }
}
