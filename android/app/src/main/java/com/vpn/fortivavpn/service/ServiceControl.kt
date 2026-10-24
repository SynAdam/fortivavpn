package com.vpn.fortivavpn.service

import android.app.Service

interface ServiceControl {
    /**
     * Gets the service instance.
     * @return The service instance.
     */
    fun getService(): Service

    /**
     * Starts the service.
     */
    fun startService()

    /**
     * Stops the service.
     */
    fun stopService()

    /**
     * The core reported that it stopped. It does so only from its stop
     * call, which runs inside a stop this service already asked for.
     * Unless a service says otherwise, this stops it again.
     */
    fun coreStopped() = stopService()

    /**
     * Protects the VPN socket.
     * @param socket The socket to protect.
     * @return True if the socket is protected, false otherwise.
     */
    fun vpnProtect(socket: Int): Boolean
}
