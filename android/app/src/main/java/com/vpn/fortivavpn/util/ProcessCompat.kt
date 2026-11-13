package com.vpn.fortivavpn.util

import android.os.Build

/**
 * Whether this process is still running, on every Android the app installs
 * on (minSdk 24).
 *
 * Process.isAlive() came with Android 8 (API 26). On Android 7 it throws
 * NoSuchMethodError. That is an Error, not an Exception, so it went through
 * the `catch (e: Exception)` around the tun2socks hand-over and ended the
 * start: no Android 7 phone or Fire OS 6 stick could connect (#444).
 *
 * exitValue() throws IllegalThreadStateException while the process runs, on
 * every version.
 */
fun Process.running(): Boolean =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        isAlive
    } else {
        try {
            exitValue()
            false
        } catch (_: IllegalThreadStateException) {
            true
        }
    }
