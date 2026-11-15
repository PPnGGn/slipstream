package com.slipstream

// Whether the incoming APK's signing certificate digests match the installed app's.
//
// Fail-closed: if either set of signer digests is empty (missing signature, unreadable
// archive, or unsupported signature scheme), the APK must not be trusted as an update.
internal fun signaturesMatch(installed: Set<String>, incoming: Set<String>): Boolean {
    if (installed.isEmpty() || incoming.isEmpty()) {
        return false
    }
    return installed.intersect(incoming).isNotEmpty()
}
