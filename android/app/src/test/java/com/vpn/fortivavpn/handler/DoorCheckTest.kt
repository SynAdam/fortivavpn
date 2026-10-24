package com.vpn.fortivavpn.handler

import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DoorCheckTest {
    @Test
    fun aTcpConnectIsNamedByHowItFailed() {
        assertEquals("timeout", DoorCheck.tcpOutcome(SocketTimeoutException("failed to connect after 2500ms")))
        assertEquals("dns", DoorCheck.tcpOutcome(UnknownHostException("cdn.example.site")))
        assertEquals(
            "refused",
            DoorCheck.tcpOutcome(ConnectException("isConnected failed: ECONNREFUSED (Connection refused)")),
        )
        assertEquals("reset", DoorCheck.tcpOutcome(ConnectException("recvfrom failed: ECONNRESET")))
        assertEquals(
            "unreachable",
            DoorCheck.tcpOutcome(ConnectException("connect failed: ENETUNREACH (Network is unreachable)")),
        )
        assertEquals("timeout", DoorCheck.tcpOutcome(ConnectException("connect failed: ETIMEDOUT")))
        assertEquals("error", DoorCheck.tcpOutcome(ConnectException("something else")))
    }

    @Test
    fun theCoreErrorKeepsItsEndOnOneLine() {
        assertNull(DoorCheck.shorten(null))
        assertNull(DoorCheck.shorten("  \n "))
        assertEquals("EOF", DoorCheck.shorten(" EOF\n"))
        val long = "a".repeat(200) + " > tls: handshake failure"
        val short = DoorCheck.shorten(long)!!
        assertEquals(DoorCheck.MAX_ERROR, short.length)
        assertEquals(true, short.startsWith("..."))
        assertEquals(true, short.endsWith("tls: handshake failure"))
    }
}
