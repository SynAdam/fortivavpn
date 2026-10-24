package com.vpn.fortivavpn.util

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import com.google.zxing.BarcodeFormat
import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.PlanarYUVLuminanceSource
import com.google.zxing.ReaderException
import com.google.zxing.common.GlobalHistogramBinarizer
import com.google.zxing.common.HybridBinarizer
import com.google.zxing.qrcode.QRCodeReader
import java.io.InputStream
import java.util.EnumMap

/**
 * Reads a QR code from a photo the camera app took of another phone's
 * screen. See handler/PeerHandoff.kt.
 *
 * A photo of a screen is nothing like a code in a picture saved from a
 * chat: it is big (12 megapixels or more), taken at an angle, a little out
 * of focus and brighter on one side. One size does not suit every photo.
 * Shrunk too far, a dense code has too few pixels per module; left too big,
 * blur spreads each module over many pixels and the finder patterns are
 * lost. So the photo is read at several sizes, [LADDER], until one gives a
 * code. On 72 simulated photos of the real codes (tilted, seen at an angle,
 * blurred, unevenly lit, 4000 by 3000 JPEG), this read 57; shrinking by
 * powers of two to 2048 and then 1024 pixels read 37.
 *
 * The photo is held as one byte of brightness per pixel, decoded through a
 * 16 bit bitmap and at most [MAX_SIDE] pixels on its longer side, so a
 * 12 megapixel photo takes about 12 MB and a 200 megapixel one no more.
 *
 * An image can be made to keep the decoder busy for minutes, so the sizes
 * are tried only while [BUDGET_MS] lasts and the caller still wants the
 * answer. Each ZXing call is not interrupted, so one call can overrun.
 */
object PhotoCodeReader {
    /** The longest side the photo is read at, larger photos are shrunk. */
    private const val MAX_SIDE = 4096

    /** How long the sizes are tried for. */
    private const val BUDGET_MS = 10_000L

    /**
     * The longer sides tried, in this order. 0 is the photo as decoded. The
     * first size and 1024 are also tried with the binarizer for even light.
     */
    private val LADDER = intArrayOf(2048, 0, 3000, 1600, 1280, 1024, 800)

    private val HINTS: Map<DecodeHintType, Any> = EnumMap<DecodeHintType, Any>(DecodeHintType::class.java).apply {
        put(DecodeHintType.TRY_HARDER, true)
        put(DecodeHintType.POSSIBLE_FORMATS, listOf(BarcodeFormat.QR_CODE))
    }

    /** One byte of brightness per pixel, row by row. */
    class Plane(val bytes: ByteArray, val width: Int, val height: Int)

    /**
     * The code in the image [open] reads, or null. [open] is called twice,
     * for the size and then the pixels, and each stream is closed here.
     * [wanted] is asked before each try; false stops. Slow: call it off the
     * main thread.
     */
    fun read(open: () -> InputStream?, wanted: () -> Boolean = { true }): String? {
        val plane = brightness(open) ?: return null
        val until = System.nanoTime() + BUDGET_MS * 1_000_000
        return decode(plane) { wanted() && System.nanoTime() < until }
    }

    /**
     * The code in [plane], or null. [keepGoing] is asked before each try.
     * No Android in here, so it runs in plain JVM tests.
     */
    fun decode(plane: Plane, keepGoing: () -> Boolean = { true }): String? {
        val longest = maxOf(plane.width, plane.height)
        val tried = HashSet<Int>()
        var first = true
        for (step in LADDER) {
            if (!keepGoing()) return null
            val target = if (step == 0) longest else minOf(step, longest)
            if (!tried.add(target)) continue
            val sized = if (target == longest) plane else shrink(plane, target)
            read(sized, hybrid = true)?.let { return it }
            if ((first || target == 1024) && keepGoing()) read(sized, hybrid = false)?.let { return it }
            first = false
        }
        return null
    }

    private fun read(plane: Plane, hybrid: Boolean): String? {
        val source = PlanarYUVLuminanceSource(
            plane.bytes, plane.width, plane.height, 0, 0, plane.width, plane.height, false,
        )
        val binarizer = if (hybrid) HybridBinarizer(source) else GlobalHistogramBinarizer(source)
        return try {
            QRCodeReader().decode(BinaryBitmap(binarizer), HINTS).text
        } catch (e: ReaderException) {
            null
        }
    }

    /** [plane] with its longer side [longest] pixels, each pixel the average of those it covers. */
    private fun shrink(plane: Plane, longest: Int): Plane {
        val w = plane.width
        val h = plane.height
        val scale = longest.toDouble() / maxOf(w, h)
        val nw = maxOf(1, (w * scale).toInt())
        val nh = maxOf(1, (h * scale).toInt())
        val xs = IntArray(nw + 1) { (it.toLong() * w / nw).toInt() }
        val ys = IntArray(nh + 1) { (it.toLong() * h / nh).toInt() }
        val src = plane.bytes
        val out = ByteArray(nw * nh)
        for (y in 0 until nh) {
            val y0 = ys[y]
            val y1 = maxOf(ys[y + 1], y0 + 1)
            for (x in 0 until nw) {
                val x0 = xs[x]
                val x1 = maxOf(xs[x + 1], x0 + 1)
                var sum = 0
                for (yy in y0 until y1) {
                    val row = yy * w
                    for (xx in x0 until x1) sum += src[row + xx].toInt() and 0xff
                }
                out[y * nw + x] = (sum / ((y1 - y0) * (x1 - x0))).toByte()
            }
        }
        return Plane(out, nw, nh)
    }

    /** The image [open] reads as brightness, at most [MAX_SIDE] pixels on its longer side. */
    private fun brightness(open: () -> InputStream?): Plane? {
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            // Returns null by design when it only reads the size, which
            // lands in bounds.
            val sizing = open() ?: return null
            sizing.use { BitmapFactory.decodeStream(it, null, bounds) }
            val side = maxOf(bounds.outWidth, bounds.outHeight)
            if (side <= 0) return null
            var sample = 1
            while (side / sample > MAX_SIDE) sample *= 2
            val options = BitmapFactory.Options().apply {
                inSampleSize = sample
                inPreferredConfig = Bitmap.Config.RGB_565
            }
            val bitmap = open()?.use { BitmapFactory.decodeStream(it, null, options) } ?: return null
            try {
                val w = bitmap.width
                val h = bitmap.height
                val out = ByteArray(w * h)
                val row = IntArray(w)
                for (y in 0 until h) {
                    bitmap.getPixels(row, 0, w, 0, y, w, 1)
                    val start = y * w
                    for (x in 0 until w) {
                        val c = row[x]
                        // ZXing's own weighting (RGBLuminanceSource): (R + 2G + B) / 4.
                        out[start + x] = (((c shr 16 and 0xff) + 2 * (c shr 8 and 0xff) + (c and 0xff)) shr 2).toByte()
                    }
                }
                Plane(out, w, h)
            } finally {
                bitmap.recycle()
            }
        } catch (e: Exception) {
            null
        } catch (e: OutOfMemoryError) {
            null
        }
    }
}
