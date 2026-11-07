package com.slipstream

// Saving the launch without starting anything (saveLaunch in the Pigeon API). The app
// calls it when the user changes a setting while no session runs, so that the tile
// starts with the current settings and not those of the last connect. Plain functions,
// testable without Android.

// Only while the service is idle. A restart of the service after the process died, and
// Reconnect from the kill switch's hold, read the saved launch: replacing it under a live
// session would bring back a different server than the one that was up. A start from the
// app writes its own launch (launchFromIntent in the service).
internal fun shouldSaveLaunch(status: VpnStatus): Boolean =
        status == VpnStatus.DISCONNECTED || status == VpnStatus.ERROR

// The launch a start from the app would have made of this message. Mirrors what
// MainActivity.startVpnService puts in the intent and launchFromIntent reads back, field
// for field and default for default; keep the three in step.
internal fun VpnConfigMessage.toLaunch(defaultGeoDir: String): VpnLaunchConfig {
    // Both or neither: the service reads a missing mode as "no split".
    val mode = splitMode
    val packages = splitPackages
    val split = mode != null && !packages.isNullOrEmpty()
    return VpnLaunchConfig(
            configJson = configJson,
            geoDir = geoAssetDir ?: defaultGeoDir,
            // Null from an older Dart build counts as off, like the Dart default.
            hijackDns = hijackDns == true,
            splitMode = if (split) mode else null,
            splitPackages = if (split) packages.orEmpty() else emptyList(),
            serverTitle = title,
            ipv6 = ipv6 == true,
            killSwitch = killSwitch == true,
    )
}
