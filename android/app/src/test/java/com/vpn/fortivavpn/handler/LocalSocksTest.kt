package com.vpn.fortivavpn.handler

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.DataInputStream
import java.io.IOException
import java.net.InetSocketAddress
import java.net.ServerSocket
import kotlin.concurrent.thread

/**
 * The credentials of the core's SOCKS port and the SOCKS5 client that sends
 * them (LocalSocks), against a fake proxy on loopback.
 */
class LocalSocksTest {
    private lateinit var rig: ConfigRig

    @Before
    fun setUp() {
        rig = ConfigRig()
        LocalSocks.clear()
    }

    @After
    fun tearDown() {
        LocalSocks.clear()
        rig.close()
    }

    @Test
    fun eachStartGetsNewHexCredentials() {
        val first = LocalSocks.renew()
        assertEquals(32, first.user.length)
        assertEquals(64, first.pass.length)
        assertTrue(Regex("^[0-9a-f]+$").matches(first.user + first.pass))
        val second = LocalSocks.renew()
        assertNotEquals(first, second)
        assertEquals(second, LocalSocks.current())
    }

    @Test
    fun theStoreCarriesThemToTheOtherProcess() {
        val auth = LocalSocks.renew()
        assertEquals("${auth.user}:${auth.pass}", MmkvManager.decodeSettingsString(com.vpn.fortivavpn.AppConfig.PREF_LOCAL_SOCKS_AUTH))
        assertEquals(auth, LocalSocks.parse("${auth.user}:${auth.pass}"))
        assertNull(LocalSocks.parse(""))
        assertNull(LocalSocks.parse(":x"))
        assertNull(LocalSocks.parse("x:"))
    }

    @Test
    fun aStopTakesThemAway() {
        LocalSocks.renew()
        LocalSocks.clear()
        assertNull(LocalSocks.current())
    }

    @Test
    fun theAnswerNamesThePortAndTheCredentials() {
        val auth = LocalSocks.Auth("u", "p")
        assertEquals(mapOf("port" to 10808, "user" to "u", "pass" to "p"), LocalSocks.answer(10808, auth))
        assertEquals(mapOf("port" to 10808), LocalSocks.answer(10808, null))
    }

    @Test
    fun theRightCredentialsConnect() {
        val proxy = FakeSocks(want = LocalSocks.Auth("user1", "pass1"))
        LocalSocks.connectVia(proxy.address, "example.com", 443, 2000, LocalSocks.Auth("user1", "pass1")).use { }
        proxy.join()
        assertEquals(listOf(5, 2, 0, 2), proxy.hello)
        assertEquals("example.com:443", proxy.target)
    }

    @Test
    fun wrongCredentialsAreRefused() {
        val proxy = FakeSocks(want = LocalSocks.Auth("user1", "pass1"))
        try {
            LocalSocks.connectVia(proxy.address, "example.com", 443, 2000, LocalSocks.Auth("user1", "nope")).use { }
            fail("connected with the wrong password")
        } catch (e: IOException) {
            assertEquals("proxy refused the credentials", e.message)
        }
        proxy.join()
    }

    @Test
    fun aProxyThatAsksForNoneStillWorks() {
        val proxy = FakeSocks(want = null)
        LocalSocks.connectVia(proxy.address, "example.com", 80, 2000, LocalSocks.Auth("user1", "pass1")).use { }
        proxy.join()
        assertEquals("example.com:80", proxy.target)
    }

    @Test
    fun withoutCredentialsOnlyNoAuthenticationIsOffered() {
        val proxy = FakeSocks(want = null)
        LocalSocks.connectVia(proxy.address, "example.com", 80, 2000, null).use { }
        proxy.join()
        assertEquals(listOf(5, 1, 0), proxy.hello)
    }

    @Test
    fun anAnswerIsReadUpToItsBody() {
        val (code, body) = LocalSocks.readResponse(
            ByteArrayInputStream("HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n".toByteArray()),
        )
        assertEquals(204, code)
        assertEquals(-1, body.read())
        val (ok, bytes) = LocalSocks.readResponse(
            ByteArrayInputStream("HTTP/1.1 200 OK\r\nServer: x\r\n\r\nabc".toByteArray()),
        )
        assertEquals(200, ok)
        assertEquals("abc", bytes.readBytes().toString(Charsets.US_ASCII))
    }

    /**
     * One SOCKS5 connection: it takes [want]'s credentials, or none when
     * [want] is null, and answers a CONNECT as done.
     */
    private class FakeSocks(want: LocalSocks.Auth?) {
        private val server = ServerSocket(0, 1, java.net.InetAddress.getLoopbackAddress())
        val address = InetSocketAddress(server.inetAddress, server.localPort)
        var hello: List<Int> = emptyList()
        var target: String? = null
        private val worker = thread {
            server.use { s ->
                s.accept().use { c ->
                    val input = DataInputStream(c.getInputStream())
                    val out = c.getOutputStream()
                    val version = input.readUnsignedByte()
                    val count = input.readUnsignedByte()
                    val methods = (0 until count).map { input.readUnsignedByte() }
                    hello = listOf(version, count) + methods
                    if (want == null) {
                        out.write(byteArrayOf(5, 0))
                    } else {
                        out.write(byteArrayOf(5, 2))
                        input.readUnsignedByte()
                        val user = ByteArray(input.readUnsignedByte()).also { input.readFully(it) }.toString(Charsets.UTF_8)
                        val pass = ByteArray(input.readUnsignedByte()).also { input.readFully(it) }.toString(Charsets.UTF_8)
                        if (user != want.user || pass != want.pass) {
                            out.write(byteArrayOf(1, 1))
                            return@thread
                        }
                        out.write(byteArrayOf(1, 0))
                    }
                    input.readUnsignedByte()
                    input.readUnsignedByte()
                    input.readUnsignedByte()
                    val type = input.readUnsignedByte()
                    check(type == 3) { "not a name" }
                    val name = ByteArray(input.readUnsignedByte()).also { input.readFully(it) }.toString(Charsets.UTF_8)
                    val port = input.readUnsignedShort()
                    target = "$name:$port"
                    out.write(byteArrayOf(5, 0, 0, 1, 127, 0, 0, 1, 0, 80))
                    out.flush()
                }
            }
        }

        fun join() = worker.join(5000)
    }
}
