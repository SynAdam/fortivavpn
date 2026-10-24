package com.vpn.fortivavpn.handler

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class InviteShareTest {
    private val activities = listOf(
        "org.telegram.messenger" to "org.telegram.ui.LaunchActivity",
        "ir.eitaa.messenger" to "ir.eitaa.ui.LaunchActivity",
        "ir.eitaa.messenger" to "ir.eitaa.ui.ShareActivity",
        "net.iGap" to "net.iGap.activities.ActivityMain",
        "com.whatsapp" to "com.whatsapp.contact.picker.ContactPicker",
        "app.rbmain.a" to "app.rbmain.a.ShareActivity",
    )

    @Test
    fun keepsExactlyTheListedPackages() {
        val hidden = InviteShare.excludedNames(activities, listOf("app.rbmain.a", "net.iGap"))
        assertEquals(
            listOf(
                "net.iGap" to "net.iGap.activities.ActivityMain",
                "app.rbmain.a" to "app.rbmain.a.ShareActivity",
            ),
            hidden,
        )
    }

    @Test
    fun keepsEveryActivityOfOnePackage() {
        val hidden = InviteShare.excludedNames(activities, listOf("ir.eitaa.messenger"))
        assertEquals(
            listOf(
                "ir.eitaa.messenger" to "ir.eitaa.ui.LaunchActivity",
                "ir.eitaa.messenger" to "ir.eitaa.ui.ShareActivity",
            ),
            hidden,
        )
    }

    @Test
    fun comparesPackageNamesWithCase() {
        assertTrue(InviteShare.excludedNames(activities, listOf("net.igap")).isEmpty())
        assertEquals(1, InviteShare.excludedNames(activities, listOf("net.iGap")).size)
    }

    @Test
    fun anEmptyListHidesNothing() {
        assertTrue(InviteShare.excludedNames(activities, emptyList()).isEmpty())
        assertTrue(InviteShare.excludedNames(emptyList(), listOf("ir.eitaa.messenger")).isEmpty())
    }
}
