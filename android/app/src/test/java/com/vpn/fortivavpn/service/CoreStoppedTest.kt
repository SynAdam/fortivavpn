package com.vpn.fortivavpn.service

import android.app.Service
import android.util.Log
import org.junit.Assert.assertEquals
import org.junit.Test
import org.mockito.Mockito

class CoreStoppedTest {
    /**
     * The core reports its shutdown from inside a stop the tunnel service
     * already made. Answered with another stop, it marked the next start as
     * stopped and that start never began. See V2RayVpnService.coreStopped.
     */
    @Test
    fun theTunnelServiceDoesNotStopAgainWhenItsCoreStops() {
        Mockito.mockStatic(Log::class.java).use {
            val service = Mockito.mock(V2RayVpnService::class.java, Mockito.CALLS_REAL_METHODS)
            // The real stop needs the core's native library.
            Mockito.doNothing().`when`(service).stopService()
            service.coreStopped()
            Mockito.verify(service, Mockito.never()).stopService()
        }
    }

    @Test
    fun anyOtherServiceStillStopsWhenItsCoreStops() {
        var stops = 0
        val other = object : ServiceControl {
            override fun getService(): Service = throw UnsupportedOperationException()
            override fun startService() {}
            override fun stopService() {
                stops++
            }
            override fun vpnProtect(socket: Int) = true
        }
        other.coreStopped()
        assertEquals(1, stops)
    }
}
