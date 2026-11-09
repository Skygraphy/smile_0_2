package com.smile.smile_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
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
                    val file = File(dir, "${now}_$i.$ext")
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

    @Suppress("DEPRECATION")
    private fun streamOf(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else intent.getParcelableExtra(Intent.EXTRA_STREAM)

    @Suppress("DEPRECATION")
    private fun streamsOf(intent: Intent): List<Uri>? =
        if (Build.VERSION.SDK_INT >= 33) intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
}
