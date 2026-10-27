package com.vpn.fortivavpn.handler

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import androidx.core.content.FileProvider
import com.vpn.fortivavpn.util.PhotoCodeReader
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/**
 * Gets the fallback file from another phone: a photo of the QR codes that
 * phone shows, or a file it sent (the text, or an image of the codes). See
 * PeerReceiveScreen on the Dart side.
 *
 * The photo is taken by the phone's own camera app, so this app needs no
 * camera permission. It declares none (the manifest removes the one a
 * library brings in), and Android lets an app without one ask the camera
 * app for a photo. The photo stays in this app's cache and is deleted as
 * soon as it has been read.
 *
 * Android often stops this app while the camera app is open, on a phone
 * with little memory. The answer then reaches a new activity whose Dart
 * side never asked: it is read anyway and kept here ([takeLeftover]) for
 * the home screen to pick up when it starts.
 *
 * Every answer is a map with "status": "ok" (with "text"), "cancelled",
 * "no_photo" (the camera app said it took one but handed none back),
 * "no_code" (an image with no code in it), "unavailable" (no camera app or
 * file picker on this device) or "unreadable" (a file that could not be
 * read, or is too big to be ours).
 */
class PeerHandoff(private val activity: Activity) {
    private var pending: MethodChannel.Result? = null

    /** Open the camera app, and read the code in the photo it takes. */
    fun photograph(result: MethodChannel.Result) {
        settle()
        forgetPicked(activity)
        val file = photoFile(activity)
        val uri = try {
            file.parentFile?.mkdirs()
            file.delete()
            FileProvider.getUriForFile(activity, "${activity.packageName}.provider", file)
        } catch (e: Exception) {
            Log.w(TAG, "No place for a photo: ${e.message}")
            result.success(mapOf("status" to "unavailable"))
            return
        }
        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
            putExtra(MediaStore.EXTRA_OUTPUT, uri)
            // Some camera apps take the grant from the clip, not the extra.
            clipData = ClipData.newRawUri("", uri)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        pending = result
        if (!start(intent, REQUEST_PHOTO)) {
            pending = null
            result.success(mapOf("status" to "unavailable"))
        }
    }

    /** Open the system file picker, and read the file the user picks. */
    fun openFile(result: MethodChannel.Result) {
        settle()
        forgetPicked(activity)
        pending = result
        // Any type: a file sent over Bluetooth or saved from a messenger
        // can arrive as text, HTML, an image or nothing in particular.
        val open = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
        }
        val get = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
        }
        if (!start(open, REQUEST_FILE) && !start(get, REQUEST_FILE)) {
            pending = null
            result.success(mapOf("status" to "unavailable"))
        }
    }

    /** Whether [requestCode] was one of these, which it then answers. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PHOTO && requestCode != REQUEST_FILE) return false
        val result = pending
        pending = null
        val generation = generations.incrementAndGet()
        val app = activity.applicationContext
        // Null: this activity never asked, because Android stopped the app
        // while the camera app or the picker was open.
        val answer: (Map<String, String>) -> Unit
        if (result != null) {
            answer = { reply -> main.post { result.success(reply) } }
        } else {
            startLeftover()
            answer = { reply -> finishLeftover(reply) }
        }
        if (requestCode == REQUEST_PHOTO) {
            readPhoto(app, resultCode, generation, answer)
        } else {
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                answer(mapOf("status" to "cancelled"))
            } else {
                readFile(app, uri, generation, answer)
            }
        }
        return true
    }

    /**
     * Read the photo whatever the camera app answered: several hand back
     * "cancelled" after saving it. No photo after "OK" is a camera app that
     * ignored where to save it; no photo after anything else is a cancel.
     */
    private fun readPhoto(
        context: Context,
        resultCode: Int,
        generation: Int,
        answer: (Map<String, String>) -> Unit,
    ) {
        val file = photoFile(context)
        if (!file.exists() || file.length() == 0L) {
            file.delete()
            answer(mapOf("status" to if (resultCode == Activity.RESULT_OK) "no_photo" else "cancelled"))
            return
        }
        decoder.execute {
            val text = try {
                PhotoCodeReader.read(file) { generations.get() == generation }
            } catch (e: Throwable) {
                Log.w(TAG, "Could not read the photo: ${e.message}")
                null
            } finally {
                file.delete()
            }
            answer(if (text == null) mapOf("status" to "no_code") else mapOf("status" to "ok", "text" to text))
        }
    }

    /**
     * Read the picked file: the text the other phone sent, or an image of
     * its codes (a screenshot sent over a messenger, or a photo taken
     * earlier), which is read like a photo from the camera app.
     */
    private fun readFile(
        context: Context,
        uri: Uri,
        generation: Int,
        answer: (Map<String, String>) -> Unit,
    ) {
        decoder.execute {
            val reply = try {
                if (isImage(context, uri)) {
                    // Read from a copy in this app's cache: PhotoCodeReader
                    // decodes files only.
                    val copy = pickedFile(context)
                    try {
                        if (!copyAtMost(context, uri, copy, MAX_IMAGE_BYTES)) {
                            mapOf("status" to "unreadable")
                        } else {
                            val text = PhotoCodeReader.read(copy) { generations.get() == generation }
                            if (text == null) mapOf("status" to "no_code") else mapOf("status" to "ok", "text" to text)
                        }
                    } finally {
                        copy.delete()
                    }
                } else {
                    val bytes = readAtMost(context, uri, MAX_FILE_BYTES)
                    if (bytes == null) {
                        mapOf("status" to "unreadable")
                    } else {
                        mapOf("status" to "ok", "text" to String(bytes, Charsets.UTF_8))
                    }
                }
            } catch (e: Throwable) {
                Log.w(TAG, "Could not read the picked file: ${e.message}")
                mapOf("status" to "unreadable")
            }
            answer(reply)
        }
    }

    /**
     * Whether [uri] is an image: by its type, or by its first bytes when a
     * provider reports no type or a wrong one (an image saved without an
     * extension).
     */
    private fun isImage(context: Context, uri: Uri): Boolean {
        if (context.contentResolver.getType(uri)?.startsWith("image/") == true) return true
        val head = ByteArray(12)
        val n = context.contentResolver.openInputStream(uri)?.use { it.read(head) } ?: return false
        if (n < 4) return false
        fun at(i: Int) = head[i].toInt() and 0xff
        val jpeg = at(0) == 0xFF && at(1) == 0xD8 && at(2) == 0xFF
        val png = at(0) == 0x89 && at(1) == 0x50 && at(2) == 0x4E && at(3) == 0x47
        val gif = at(0) == 0x47 && at(1) == 0x49 && at(2) == 0x46
        val bmp = at(0) == 0x42 && at(1) == 0x4D
        val webp = n >= 12 && String(head, 0, 4, Charsets.US_ASCII) == "RIFF" &&
            String(head, 8, 4, Charsets.US_ASCII) == "WEBP"
        val heif = n >= 12 && String(head, 4, 4, Charsets.US_ASCII) == "ftyp"
        return jpeg || png || gif || bmp || webp || heif
    }

    /** The file's bytes, or null when it is longer than [limit] or cannot be opened. */
    private fun readAtMost(context: Context, uri: Uri, limit: Int): ByteArray? {
        return context.contentResolver.openInputStream(uri)?.use { input ->
            val out = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (out.size() <= limit) {
                val n = input.read(buffer)
                if (n < 0) break
                out.write(buffer, 0, n)
            }
            if (out.size() > limit) null else out.toByteArray()
        }
    }

    /**
     * Copies the file at [uri] to [to]. False, with nothing left at [to],
     * when it is longer than [limit] or cannot be opened.
     */
    private fun copyAtMost(context: Context, uri: Uri, to: File, limit: Long): Boolean {
        to.parentFile?.mkdirs()
        val copied = context.contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(to).use { out ->
                val buffer = ByteArray(64 * 1024)
                var total = 0L
                while (total <= limit) {
                    val n = input.read(buffer)
                    if (n < 0) break
                    out.write(buffer, 0, n)
                    total += n
                }
                total <= limit
            }
        } ?: false
        if (!copied) to.delete()
        return copied
    }

    private fun start(intent: Intent, requestCode: Int): Boolean = try {
        activity.startActivityForResult(intent, requestCode)
        true
    } catch (e: ActivityNotFoundException) {
        false
    } catch (e: SecurityException) {
        Log.w(TAG, "Not allowed to open ${intent.action}: ${e.message}")
        false
    }

    /**
     * Answer a request still waiting, so its Dart future does not hang, and
     * stop a decode still running for it.
     */
    private fun settle() {
        generations.incrementAndGet()
        pending?.success(mapOf("status" to "cancelled"))
        pending = null
    }

    companion object {
        private const val TAG = "PeerHandoff"

        // After the VPN consent request (1101) and the notification
        // permission request (1102) in MainActivity.
        const val REQUEST_PHOTO = 1103
        const val REQUEST_FILE = 1104

        /** Bootstrap.maxBytes on the Dart side: the file is a few KB. */
        private const val MAX_FILE_BYTES = 256 * 1024

        /**
         * The largest picked image read. A photo from a 200 megapixel
         * camera is about 30 to 50 MB.
         */
        private const val MAX_IMAGE_BYTES = 64L * 1024 * 1024

        private val main = Handler(Looper.getMainLooper())

        /** One decode at a time: each can take seconds and most of the memory it is given. */
        private val decoder = Executors.newSingleThreadExecutor()

        /** Bumped by every new request, which stops the decode before it. */
        private val generations = AtomicInteger()

        // An answer that reached an activity whose Dart side never asked.
        // Touched on the main thread only.
        private var leftover: Map<String, String>? = null
        private var leftoverBusy = false
        private val leftoverWaiters = mutableListOf<MethodChannel.Result>()

        private fun photoFile(context: Context) = File(File(context.cacheDir, "peer"), "code.jpg")

        private fun pickedFile(context: Context) = File(File(context.cacheDir, "peer"), "picked")

        /**
         * Deletes a copy of a picked image that an earlier read left
         * behind, when the process ended before readFile's finally ran. On
         * the decoder's thread, after any read still going.
         */
        private fun forgetPicked(context: Context) {
            val copy = pickedFile(context.applicationContext)
            decoder.execute { copy.delete() }
        }

        private fun startLeftover() {
            leftover = null
            leftoverBusy = true
        }

        private fun finishLeftover(answer: Map<String, String>) {
            main.post {
                leftoverBusy = false
                leftover = answer
                val waiting = leftoverWaiters.toList()
                leftoverWaiters.clear()
                waiting.forEach { takeLeftover(it) }
            }
        }

        /**
         * The answer that came back while the Dart side was not there to
         * hear it, once, or null. Waits for it while it is still being
         * read. Main thread only.
         */
        fun takeLeftover(result: MethodChannel.Result) {
            if (leftoverBusy) {
                leftoverWaiters.add(result)
                return
            }
            val answer = leftover
            leftover = null
            result.success(answer)
        }
    }
}
