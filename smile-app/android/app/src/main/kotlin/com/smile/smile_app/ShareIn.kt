package com.smile.smile_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Photos and videos shared to Smile from another app (2026-11-09): copied
 * into Smile's cache at once (the other app's permission to read them ends
 * with the share), then handed to Dart (share_in.dart) on "take". Never on
 * a Frame: there the share target is switched off (MainActivity.setLauncher).
 */
object ShareIn {
    @Volatile
    private var pending: List<String> = emptyList()

    /** Set while Smile's Dart code runs. */
    @Volatile
    var channel: MethodChannel? = null

    fun take(): List<String> {
        val taken = pending
        pending = emptyList()
        return taken
    }

    fun handle(context: Context, intent: Intent?) {
        if (intent == null || MainActivity.isFrame(context)) return
        val action = intent.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return
        val uris = mutableListOf<Uri>()
        if (action == Intent.ACTION_SEND) streamOf(intent)?.let { uris.add(it) } else streamsOf(intent)?.let { uris.addAll(it) }
        // Some apps put them only in the clip data.
        if (uris.isEmpty()) {
            val clip = intent.clipData
            if (clip != null) for (i in 0 until clip.itemCount) clip.getItemAt(i).uri?.let { uris.add(it) }
        }
        val sharedType = intent.type ?: ""
        // Handled once, not again when the activity is recreated.
        intent.action = null
        if (uris.isEmpty()) return
        val app = context.applicationContext
        Thread {
            val dir = File(app.cacheDir, "shared_in").apply { mkdirs() }
            // Older shares are long in the upload queue (it keeps its own copy).
            val now = System.currentTimeMillis()
            dir.listFiles()?.forEach { if (now - it.lastModified() > 24 * 3600 * 1000L) it.delete() }
            val paths = mutableListOf<String>()
            uris.forEachIndexed { i, uri ->
                try {
                    val type = app.contentResolver.getType(uri) ?: sharedType
                    if (!type.startsWith("image/") && !type.startsWith("video/")) return@forEachIndexed
                    val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(type)
                        ?: if (type.startsWith("video/")) "mp4" else "jpg"
                    // When it was taken, carried in the name ("_t<ms>"): a
                    // WhatsApp picture has no EXIF date left (2026-11-25).
                    val taken = takenAtOf(app, uri)
                    val file = File(dir, if (taken != null) "${now}_${i}_t$taken.$ext" else "${now}_$i.$ext")
                    app.contentResolver.openInputStream(uri)?.use { input -> file.outputStream().use { input.copyTo(it) } }
                    if (file.length() > 0) paths.add(file.absolutePath) else file.delete()
                } catch (_: Exception) {
                }
            }
            if (paths.isEmpty()) return@Thread
            pending = paths
            Handler(Looper.getMainLooper()).post { channel?.invokeMethod("available", null) }
        }.start()
    }

    private val nameDate = Regex("""(?<!\d)((?:19|20)\d{2})(\d{2})(\d{2})(?:[_-]?(\d{2})(\d{2})(\d{2}))?(?!\d)""")

    /**
     * The gallery's date for it: MediaStore's DATE_TAKEN, else the file's
     * DATE_MODIFIED (what the Samsung gallery shows for a WhatsApp
     * picture), else a date in its name (IMG-20241125-WA0003.jpg) when the
     * sharing app isn't the gallery. Null when none says.
     */
    private fun takenAtOf(context: Context, uri: Uri): Long? {
        var name: String? = null
        try {
            context.contentResolver.query(uri, null, null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    val ti = c.getColumnIndex(MediaStore.MediaColumns.DATE_TAKEN)
                    if (ti >= 0 && !c.isNull(ti) && c.getLong(ti) > 0) return c.getLong(ti)
                    // No date in it: the Samsung gallery shows the file's
                    // date then, not the one in its name (2026-11-25: a
                    // WhatsApp picture named ...20241124... it shows on
                    // the 25th).
                    val mi = c.getColumnIndex(MediaStore.MediaColumns.DATE_MODIFIED)
                    if (mi >= 0 && !c.isNull(mi) && c.getLong(mi) > 0) {
                        val ms = c.getLong(mi) * 1000L
                        if (ms <= System.currentTimeMillis() + 86_400_000L) return ms
                    }
                    val ni = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (ni >= 0) name = c.getString(ni)
                }
            }
        } catch (_: Exception) {
        }
        val n = name ?: uri.lastPathSegment ?: return null
        val m = nameDate.find(n) ?: return null
        return try {
            val (y, mo, d) = Triple(m.groupValues[1].toInt(), m.groupValues[2].toInt(), m.groupValues[3].toInt())
            if (mo !in 1..12 || d !in 1..31) return null
            val h = m.groupValues[4].toIntOrNull() ?: 12
            val mi = m.groupValues[5].toIntOrNull() ?: 0
            val s = m.groupValues[6].toIntOrNull() ?: 0
            val cal = java.util.Calendar.getInstance()
            cal.clear()
            cal.set(y, mo - 1, d, h, mi, s)
            val ms = cal.timeInMillis
            if (ms > System.currentTimeMillis() + 86_400_000L) null else ms
        } catch (_: Exception) {
            null
        }
    }

    @Suppress("DEPRECATION")
    private fun streamOf(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else intent.getParcelableExtra(Intent.EXTRA_STREAM)

    @Suppress("DEPRECATION")
    private fun streamsOf(intent: Intent): List<Uri>? =
        if (Build.VERSION.SDK_INT >= 33) intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
}
