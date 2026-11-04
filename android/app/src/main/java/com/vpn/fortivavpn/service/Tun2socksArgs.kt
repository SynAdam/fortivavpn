package com.vpn.fortivavpn.service

import com.vpn.fortivavpn.handler.LocalSocks

/**
 * The command line tun2socks starts with (V2RayVpnService.startTun2socks),
 * apart from the service so it can be checked on the JVM.
 */
internal object Tun2socksArgs {
    /**
     * The command for the bundled badvpn tun2socks. With [auth] it sends
     * the core's SOCKS credentials: the user name, and the password from
     * [passwordPath], or on the command line when there is no file. It
     * offers no authentication too, so a core port that asks for none
     * still works.
     */
    fun build(
        binary: String,
        routerAddress: String,
        socksAddress: String,
        mtu: Int,
        sockPath: String,
        auth: LocalSocks.Auth?,
        passwordPath: String?,
        debugBuild: Boolean,
    ): ArrayList<String> {
        val cmd = arrayListOf(
            binary,
            "--netif-ipaddr", routerAddress,
            "--netif-netmask", "255.255.255.252",
            "--socks-server-addr", socksAddress,
            "--tunmtu", mtu.toString(),
            "--sock-path", sockPath,
            // UDP as SOCKS5 UDP ASSOCIATE, which the core's SOCKS inbound
            // accepts. In this build --enable-udprelay means the udpgw
            // protocol aimed at 0.0.0.0:0, which the core does not speak, so
            // every UDP packet was dropped: DNS over UDP, voice calls, games.
            // DNS still worked only because Android upgrades its own lookups
            // to DNS over TLS when it can. With Private DNS set to a
            // provider it cannot, and on 2026-10-02 a phone in Iran
            // connected but could not resolve a single new name.
            "--socks5-udp",
            "--loglevel", logLevel(debugBuild),
        )
        if (auth != null) {
            cmd.add("--username")
            cmd.add(auth.user)
            if (passwordPath != null) {
                cmd.add("--password-file")
                cmd.add(passwordPath)
            } else {
                cmd.add("--password")
                cmd.add(auth.pass)
            }
        }
        return cmd
    }

    /**
     * The badvpn log level: `debug` in a debug build, `warning` in a
     * release. At `debug` it wrote about 950 lines a minute to logcat with
     * the screen off and nothing passing (its timers and epoll wake-ups),
     * in the release build too (emulator test, 2026-11-04). Each line costs
     * the process a pipe read and a logcat write.
     */
    fun logLevel(debugBuild: Boolean): String = if (debugBuild) "debug" else "warning"

    /** [cmd] as the log shows it: the credentials as `<set>`. */
    fun forLog(cmd: List<String>): String =
        cmd.mapIndexed { i, arg ->
            val flag = cmd.getOrNull(i - 1)
            if (flag == "--username" || flag == "--password") "<set>" else arg
        }.joinToString(" ")
}
