package com.vpn.fortivavpn

import android.app.Activity
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ImePaddingTest {
    // MainActivity is a FlutterActivity; Flutter handles the keyboard there.
    @Test
    fun theFlutterScreenKeepsItsOwnKeyboardHandling() {
        assertFalse(AngApplication.needsImePadding(MainActivity::class.java))
    }

    @Test
    fun anyOtherScreenStillGetsThePadding() {
        assertTrue(AngApplication.needsImePadding(Activity::class.java))
    }
}
