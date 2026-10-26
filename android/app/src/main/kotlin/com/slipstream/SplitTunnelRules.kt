package com.slipstream

data class SplitTunnelOutcome(
        val applied: Int,
        val skipped: Int,
        val fellBackToFullTunnel: Boolean,
)

// Decides which apps the VpnService.Builder keeps out of (or lets into) the
// tunnel. allow/disallow wrap the Builder calls and return false for a package
// that is no longer installed. A Builder takes either allowed or disallowed
// apps, never both, so exactly one of the two lists is ever filled.
internal fun applySplitTunnel(
        mode: VpnSplitMode?,
        packages: List<String>,
        ownPackage: String,
        allow: (String) -> Boolean,
        disallow: (String) -> Boolean,
): SplitTunnelOutcome {
    if (mode == null || packages.isEmpty()) {
        disallow(ownPackage)
        return SplitTunnelOutcome(applied = 0, skipped = 0, fellBackToFullTunnel = false)
    }
    val picked = packages.filter { it != ownPackage }.distinct()

    return when (mode) {
        VpnSplitMode.BYPASS -> {
            disallow(ownPackage)
            val applied = picked.count(disallow)
            SplitTunnelOutcome(applied, picked.size - applied, fellBackToFullTunnel = false)
        }
        VpnSplitMode.PROXY -> {
            val applied = picked.count(allow)
            if (applied == 0) {
                // An empty allow list would tunnel every app, ours included, and
                // the core's own connections would loop back into the tunnel.
                disallow(ownPackage)
                SplitTunnelOutcome(applied = 0, skipped = picked.size, fellBackToFullTunnel = true)
            } else {
                SplitTunnelOutcome(applied, picked.size - applied, fellBackToFullTunnel = false)
            }
        }
    }
}
