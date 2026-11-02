package com.slipstream

// Whether it is safe to ask the system about the VPN permission now.
//
// VpnService.prepare() is not a harmless question. When this app's own VPN is the
// current one, it unprepares it: the system switches to the legacy VPN and calls
// onRevoke, which tears the tunnel down, or removes the kill switch's blocking
// interface and opens the traffic, just to find out something we already know.
// While the service is active the permission is plainly granted, so ask only when
// it is idle.
internal fun shouldAskPermission(status: VpnStatus): Boolean =
        status == VpnStatus.DISCONNECTED || status == VpnStatus.ERROR
