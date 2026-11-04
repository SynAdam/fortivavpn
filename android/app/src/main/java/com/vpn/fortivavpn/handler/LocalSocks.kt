package com.vpn.fortivavpn.handler

import com.vpn.fortivavpn.AppConfig
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.net.InetSocketAddress
import java.net.Socket
import java.security.SecureRandom

/**
 * The credentials of the core's local SOCKS port, made new for every start
 * of the core, and a small SOCKS5 client that uses them.
 *
 * Without them any app on the phone could send its traffic through the
 * tunnel by this port, read the address it leaves from, or find that a
 * proxy runs. Only this app and tun2socks know the credentials.
 *
 * They cover the core's own port only. On the backup network the core's
 * proxy outbound dials the backup library's own local SOCKS port
 * (PsiphonSession, PsiphonConfig), and that library asks for no
 * credentials and takes none from its config. While that session runs,
 * another app that finds that port can still use the tunnel through it.
 *
 * They are made in the tunnel's process ([renew], before any config of
 * that start is built), kept in memory there and in the settings store,
 * which the app's main process reads ([current]). The store is in the
 * app's private storage, and the app allows no backup.
 */
object LocalSocks {
    data class Auth(val user: String, val pass: String)

    @Volatile
    private var held: Auth? = null

    private val random = SecureRandom()

    /**
     * New credentials for the start of the core that is about to happen:
     * a 16 byte user name and a 32 byte password, as hex. RFC 1929 allows
     * up to 255 bytes for each.
     */
    fun renew(): Auth {
        val auth = Auth(hex(16), hex(32))
        held = auth
        try {
            MmkvManager.encodeSettings(AppConfig.PREF_LOCAL_SOCKS_AUTH, "${auth.user}:${auth.pass}")
        } catch (_: Exception) {
            // The tunnel's process has them in memory. The main process
            // then finds none, and its checks through the port fail
            // rather than go through it without them.
        }
        return auth
    }

    /** The credentials of the running start of the core, or null. */
    fun current(): Auth? = held ?: try {
        parse(MmkvManager.decodeSettingsString(AppConfig.PREF_LOCAL_SOCKS_AUTH))
    } catch (_: Exception) {
        null
    }

    /** The core stopped: its credentials are gone with it. */
    fun clear() {
        held = null
        try {
            MmkvManager.encodeSettings(AppConfig.PREF_LOCAL_SOCKS_AUTH, null as String?)
        } catch (_: Exception) {
        }
    }

    /** What the app's method channels answer: the port and the credentials. */
    fun answer(port: Int, auth: Auth? = current()): Map<String, Any> =
        if (auth == null) mapOf("port" to port) else mapOf("port" to port, "user" to auth.user, "pass" to auth.pass)

    internal fun parse(stored: String?): Auth? {
        if (stored.isNullOrEmpty()) return null
        val at = stored.indexOf(':')
        if (at <= 0 || at == stored.length - 1) return null
        return Auth(stored.substring(0, at), stored.substring(at + 1))
    }

    private fun hex(bytes: Int): String {
        val raw = ByteArray(bytes)
        random.nextBytes(raw)
        return raw.joinToString("") { "%02x".format(it.toInt() and 0xff) }
    }

    /**
     * A socket to [host]:[port] through the core's SOCKS port on loopback,
     * with the running credentials when there are any. The name is sent to
     * the core as a name, so it is looked up there, as before.
     * Blocking: call off the main thread. The caller closes the socket.
     */
    fun connect(host: String, port: Int, timeoutMs: Int, auth: Auth? = current()): Socket =
        connectVia(InetSocketAddress(AppConfig.LOOPBACK, SettingsManager.getSocksPort()), host, port, timeoutMs, auth)

    /** [connect] through the proxy at [proxy], for tests. */
    internal fun connectVia(proxy: InetSocketAddress, host: String, port: Int, timeoutMs: Int, auth: Auth?): Socket {
        val socket = Socket()
        try {
            socket.soTimeout = timeoutMs
            socket.connect(proxy, timeoutMs)
            handshake(socket, host, port, auth)
            return socket
        } catch (e: Exception) {
            try {
                socket.close()
            } catch (_: Exception) {
            }
            throw e
        }
    }

    /** The SOCKS5 hello, the RFC 1929 sub-negotiation when asked for, and a CONNECT by name. */
    internal fun handshake(socket: Socket, host: String, port: Int, auth: Auth?) {
        val out = socket.getOutputStream()
        val input = socket.getInputStream()
        out.write(if (auth != null) byteArrayOf(5, 2, 0, 2) else byteArrayOf(5, 1, 0))
        out.flush()
        val hello = readFully(input, 2)
        if (hello[0].toInt() != 5) throw IOException("not a SOCKS5 proxy")
        when (hello[1].toInt() and 0xff) {
            0x00 -> Unit
            0x02 -> {
                if (auth == null) throw IOException("proxy asked for credentials")
                val user = auth.user.toByteArray(Charsets.UTF_8)
                val pass = auth.pass.toByteArray(Charsets.UTF_8)
                if (user.size > 255 || pass.size > 255) throw IOException("credentials too long")
                val request = ByteArrayOutputStream()
                request.write(1)
                request.write(user.size)
                request.write(user)
                request.write(pass.size)
                request.write(pass)
                out.write(request.toByteArray())
                out.flush()
                val verdict = readFully(input, 2)
                if (verdict[1].toInt() != 0) throw IOException("proxy refused the credentials")
            }
            else -> throw IOException("proxy refused every method offered")
        }
        val name = host.toByteArray(Charsets.UTF_8)
        if (name.size > 255) throw IOException("host name too long")
        val connect = ByteArrayOutputStream()
        connect.write(byteArrayOf(5, 1, 0, 3))
        connect.write(name.size)
        connect.write(name)
        connect.write((port shr 8) and 0xff)
        connect.write(port and 0xff)
        out.write(connect.toByteArray())
        out.flush()
        val head = readFully(input, 4)
        if (head[0].toInt() != 5) throw IOException("not a SOCKS5 reply")
        if (head[1].toInt() != 0) throw IOException("proxy could not connect (reply ${head[1].toInt() and 0xff})")
        val bound = when (head[3].toInt()) {
            1 -> 4
            4 -> 16
            3 -> readFully(input, 1)[0].toInt() and 0xff
            else -> throw IOException("unknown address type ${head[3].toInt()}")
        }
        readFully(input, bound + 2)
    }

    private fun readFully(input: InputStream, count: Int): ByteArray {
        val buffer = ByteArray(count)
        var at = 0
        while (at < count) {
            val n = input.read(buffer, at, count - at)
            if (n < 0) throw IOException("proxy closed the connection")
            at += n
        }
        return buffer
    }

    /**
     * One HTTP/1.1 GET of [path] at [host] over [socket], which already
     * leads to the server (plain, or TLS on top). Returns the status and a
     * stream of the body, which ends where the server closes the
     * connection. Asks for no compression and for the connection to close,
     * so the body is the bytes as sent.
     */
    fun httpGet(socket: Socket, host: String, path: String): Pair<Int, InputStream> {
        val request = "GET $path HTTP/1.1\r\n" +
            "Host: $host\r\n" +
            "Accept-Encoding: identity\r\n" +
            "Connection: close\r\n\r\n"
        socket.getOutputStream().apply {
            write(request.toByteArray(Charsets.US_ASCII))
            flush()
        }
        return readResponse(BufferedInputStream(socket.getInputStream()))
    }

    /** The status line and headers of an answer, and the stream of its body. */
    internal fun readResponse(input: InputStream): Pair<Int, InputStream> {
        val status = readLine(input) ?: throw IOException("no answer")
        val parts = status.split(' ')
        if (parts.size < 2 || !parts[0].startsWith("HTTP/")) throw IOException("not an HTTP answer")
        val code = parts[1].toIntOrNull() ?: throw IOException("no status")
        while (true) {
            val line = readLine(input) ?: break
            if (line.isEmpty()) break
        }
        return code to input
    }

    private fun readLine(input: InputStream): String? {
        val line = ByteArrayOutputStream()
        while (true) {
            val b = input.read()
            if (b < 0) return if (line.size() == 0) null else line.toString("ISO-8859-1")
            if (b == '\n'.code) break
            if (b != '\r'.code) line.write(b)
            if (line.size() > 16 * 1024) throw IOException("header line too long")
        }
        return line.toString("ISO-8859-1")
    }
}
