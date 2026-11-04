package com.vpn.fortivavpn.service

import com.vpn.fortivavpn.handler.LocalSocks
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The command tun2socks starts with, with and without SOCKS credentials. */
class Tun2socksArgsTest {
    private fun build(
        auth: LocalSocks.Auth?,
        passwordPath: String?,
        debugBuild: Boolean = false,
    ) = Tun2socksArgs.build(
        binary = "/lib/libtun2socks.so",
        routerAddress = "10.10.14.2",
        socksAddress = "127.0.0.1:10808",
        mtu = 1500,
        sockPath = "/files/sock_path",
        auth = auth,
        passwordPath = passwordPath,
        debugBuild = debugBuild,
    )

    private fun after(cmd: List<String>, flag: String): String? = cmd.indexOf(flag).takeIf { it >= 0 }?.let { cmd.getOrNull(it + 1) }

    @Test
    fun theCredentialsGoWithTheUserNameAndThePasswordFile() {
        val cmd = build(LocalSocks.Auth("abc", "secret"), "/nobackup/pw")
        assertEquals("abc", after(cmd, "--username"))
        assertEquals("/nobackup/pw", after(cmd, "--password-file"))
        assertFalse(cmd.contains("--password"))
        assertFalse(cmd.contains("secret"))
        assertTrue(cmd.contains("--socks5-udp"))
        assertEquals("127.0.0.1:10808", after(cmd, "--socks-server-addr"))
    }

    @Test
    fun withNoFileThePasswordGoesOnTheCommandLine() {
        val cmd = build(LocalSocks.Auth("abc", "secret"), null)
        assertEquals("abc", after(cmd, "--username"))
        assertEquals("secret", after(cmd, "--password"))
        assertFalse(cmd.contains("--password-file"))
    }

    @Test
    fun withoutCredentialsNoneAreSent() {
        val cmd = build(null, "/nobackup/pw")
        assertFalse(cmd.contains("--username"))
        assertFalse(cmd.contains("--password"))
        assertFalse(cmd.contains("--password-file"))
    }

    @Test
    fun aReleaseLogsWarningsAndADebugBuildEverything() {
        assertEquals("warning", after(build(null, null), "--loglevel"))
        assertEquals("debug", after(build(null, null, debugBuild = true), "--loglevel"))
    }

    @Test
    fun theLoggedCommandHoldsNoCredentials() {
        val logged = Tun2socksArgs.forLog(build(LocalSocks.Auth("abc", "secret"), null))
        assertFalse(logged.contains("abc"))
        assertFalse(logged.contains("secret"))
        assertTrue(logged.contains("--username <set>"))
        assertTrue(logged.contains("--password <set>"))
    }
}
