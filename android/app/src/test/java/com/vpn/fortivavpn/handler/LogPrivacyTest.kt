package com.vpn.fortivavpn.handler

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class LogPrivacyTest {
    /**
     * The sample lines the Dart test reads too, so the two filters are held
     * to the same lines. Gradle runs this test from android/app, so the file
     * is found by walking up to the Flutter project root.
     */
    private val samples: List<Pair<Boolean, String>> by lazy {
        var dir: File? = File(System.getProperty("user.dir")).absoluteFile
        while (dir != null && !File(dir, "pubspec.yaml").exists()) dir = dir.parentFile
        val file = File(dir ?: error("no pubspec.yaml above the test"), "test/fixtures/log_privacy_lines.txt")
        file.readLines()
            .filter { it.isNotBlank() && !it.startsWith("#") }
            .map { line ->
                when {
                    line.startsWith("drop ") -> true to line.removePrefix("drop ")
                    line.startsWith("keep ") -> false to line.removePrefix("keep ")
                    else -> error("a sample line must start with drop or keep: $line")
                }
            }
    }

    private val dropped get() = samples.filter { it.first }.map { it.second }
    private val kept get() = samples.filter { !it.first }.map { it.second }

    @Test
    fun theSamplesHaveBothKinds() {
        assertTrue(dropped.size > 30)
        assertTrue(kept.size > 5)
    }

    @Test
    fun everyLineThatNamesASiteOrAnAddressIsFound() {
        for (line in dropped) assertTrue(line, LogPrivacy.namesDestination(line))
    }

    @Test
    fun linesWithoutASiteOrAnAddressAreNotFound() {
        for (line in kept) assertFalse(line, LogPrivacy.namesDestination(line))
    }

    @Test
    fun aScrubbedLogHoldsOnlyTheKeptLinesAndASummary() {
        val log = samples.joinToString("\n", postfix = "\n") { it.second }
        val out = LogPrivacy.scrub(log).split('\n')
        assertEquals(kept, out.dropLast(1))
        for (line in dropped) assertFalse(line, out.contains(line))
        assertEquals(
            "[privacy] ${dropped.size} lines that name a site or an address were left out. " +
                "Of these, 2 named a 10.10.34.x sinkhole address and 1 used port 853.",
            out.last(),
        )
    }

    @Test
    fun noSiteNameOrAddressSurvivesAScrub() {
        val log = samples.joinToString("\n") { it.second }
        val out = LogPrivacy.scrub(log)
        for (name in listOf(
            "example.com", "example.org", "example.ir", "example.net", "xn--mgbh0fb", "مثال",
            "203.0.113.", "198.51.100.", "2001:db8", "10.10.34.35", "2001:4188", "Example VPN",
            "com.example.app",
        )) {
            assertFalse(name, out.contains(name))
        }
    }

    @Test
    fun theSummaryPassesTheFilterSoTheDartSideKeepsIt() {
        for (summary in listOf(
            LogPrivacy.summary(1, 0, 0),
            LogPrivacy.summary(41, 2, 5),
            LogPrivacy.summary(3, 1, 0),
        )) {
            assertFalse(summary, LogPrivacy.namesDestination(summary))
        }
        assertEquals("[privacy] 1 line that names a site or an address was left out.", LogPrivacy.summary(1, 0, 0))
        // The old search for phones that met the sinkhole still finds them.
        assertTrue(LogPrivacy.summary(3, 1, 0).contains("10.10.34."))
    }

    @Test
    fun aLogWithNothingToLeaveOutIsUnchanged() {
        val log = kept.joinToString("\n", postfix = "\n")
        assertEquals(log, LogPrivacy.scrub(log))
    }

    @Test
    fun scrubbingTwiceChangesNothingMore() {
        val once = LogPrivacy.scrub(samples.joinToString("\n") { it.second })
        assertEquals(once, LogPrivacy.scrub(once))
    }

    @Test
    fun aLogOfOnlySiteLinesBecomesTheSummary() {
        val log = dropped.take(3).joinToString("\n", postfix = "\n")
        assertEquals(LogPrivacy.summary(3, 0, 0), LogPrivacy.scrub(log))
    }
}
