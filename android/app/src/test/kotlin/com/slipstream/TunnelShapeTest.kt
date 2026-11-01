package com.slipstream

import org.junit.Assert.assertEquals
import org.junit.Test

class TunnelShapeTest {

    private fun shape(ipv6: Boolean) =
            tunnelShape(
                    address4 = "10.31.7.1",
                    prefix4 = 24,
                    address6 = "fd12:3456:789a:1::1",
                    prefix6 = 64,
                    ipv6 = ipv6,
            )

    @Test
    fun withIpv6OffOnlyIpv4IsConfigured() {
        val shape = shape(ipv6 = false)

        assertEquals(listOf(TunnelAddress("10.31.7.1", 24)), shape.addresses)
        assertEquals(listOf(TunnelRoute("0.0.0.0", 0)), shape.routes)
    }

    @Test
    fun withIpv6OnBothFamiliesAreConfigured() {
        val shape = shape(ipv6 = true)

        assertEquals(
                listOf(TunnelAddress("10.31.7.1", 24), TunnelAddress("fd12:3456:789a:1::1", 64)),
                shape.addresses,
        )
        assertEquals(listOf(TunnelRoute("0.0.0.0", 0), TunnelRoute("::", 0)), shape.routes)
    }

    @Test
    fun noIpv6AddressOrRouteLeaksIntoTheIpv4OnlyShape() {
        // Android blocks a family with no address, route or DNS server: one stray
        // IPv6 entry would switch IPv6 back on, so the whole family must be absent.
        val shape = shape(ipv6 = false)

        assertEquals(false, shape.addresses.any { it.address.contains(':') })
        assertEquals(false, shape.routes.any { it.address.contains(':') })
    }
}
