package com.slipstream

// What the VPN interface gets: the addresses and routes for VpnService.Builder.
// Kept apart from the service so the rule is testable without Android.
data class TunnelAddress(val address: String, val prefix: Int)

data class TunnelRoute(val address: String, val prefix: Int)

data class TunnelShape(val addresses: List<TunnelAddress>, val routes: List<TunnelRoute>)

// With IPv6 off the interface gets no IPv6 address and no ::/0 route. That is
// enough: Android blocks every family that has no address, route or DNS server
// on the VPN (VpnService.Builder.allowFamily), so apps fall back to IPv4 at
// once and nothing leaks around the tunnel. The DNS servers are IPv4 too.
internal fun tunnelShape(
        address4: String,
        prefix4: Int,
        address6: String,
        prefix6: Int,
        ipv6: Boolean,
): TunnelShape {
    val addresses = mutableListOf(TunnelAddress(address4, prefix4))
    val routes = mutableListOf(TunnelRoute("0.0.0.0", 0))
    if (ipv6) {
        addresses += TunnelAddress(address6, prefix6)
        routes += TunnelRoute("::", 0)
    }
    return TunnelShape(addresses, routes)
}
