package com.slipstream.sync

// Whether MainActivity's Flutter engine is up. While it is, the Dart side's own
// timer refreshes subscriptions, so the background job skips its run instead of
// starting a second engine in the same process.
object MainEngine {
    @Volatile var attached = false
}
