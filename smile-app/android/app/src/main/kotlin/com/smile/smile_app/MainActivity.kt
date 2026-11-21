package com.smile.smile_app

import android.app.Activity
import android.content.ComponentName
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A Frame: screen on from the very first moment, before Dart runs.
        if (isFrame(this)) setFrameWindow(true)
        // Shared from another app (2026-11-09) -- once, not after a rotation.
        if (savedInstanceState == null) ShareIn.handle(this, intent)
    }

    // "Screenshot melden" (2026-11-21): Android 14+ tells the app when
    // someone takes a screenshot of it; Smile then offers to report it.
    // The picture itself Smile makes of its own screen -- no gallery access.
    // Never on a Frame.
    private var screenCaptureChannel: MethodChannel? = null
    private var screenCaptureCallback: Activity.ScreenCaptureCallback? = null

    override fun onStart() {
        super.onStart()
        if (Build.VERSION.SDK_INT >= 34 && !isFrame(this)) {
            val cb = Activity.ScreenCaptureCallback { screenCaptureChannel?.invokeMethod("captured", null) }
            try {
                registerScreenCaptureCallback(mainExecutor, cb)
                screenCaptureCallback = cb
            } catch (_: Exception) {}
        }
    }

    override fun onStop() {
        if (Build.VERSION.SDK_INT >= 34) {
            screenCaptureCallback?.let { try { unregisterScreenCaptureCallback(it) } catch (_: Exception) {} }
            screenCaptureCallback = null
        }
        super.onStop()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        ShareIn.handle(this, intent)
    }

    /**
     * Only while this device is a Frame (FrameMode, 2026-10-11): never let
     * the display sleep and show over the lock screen -- a dedicated
     * display, not a phone.
     */
    private fun videoFrame(path: String?, ms: Long, width: Int): ByteArray? {
        if (path == null || !File(path).exists()) return null
        val retriever = android.media.MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            val us = ms * 1000
            val option = android.media.MediaMetadataRetriever.OPTION_CLOSEST_SYNC
            val bitmap = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                retriever.getScaledFrameAtTime(us, option, width, width)
            } else {
                retriever.getFrameAtTime(us, option)
            }) ?: return null
            val out = java.io.ByteArrayOutputStream()
            bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 80, out)
            bitmap.recycle()
            return out.toByteArray()
        } finally {
            retriever.release()
        }
    }

    private fun setFrameWindow(frame: Boolean) {
        if (frame) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(frame)
            setTurnScreenOn(frame)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smile/frame_window").setMethodCallHandler { call, result ->
            if (call.method == "setFrameMode") {
                setFrameWindow(call.arguments == true)
                setLauncher(call.arguments == true)
            }
            // Nachtruhe (2026-10-14): the display as dark as it goes, the
            // Frame shows black meanwhile; back to the system's brightness after.
            if (call.method == "setDim") {
                val attributes = window.attributes
                attributes.screenBrightness = if (call.arguments == true) 0.01f
                    else WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                window.attributes = attributes
            }
            // "Bild dreht sich mit dem Frame" (2026-10-17).
            if (call.method == "setOrientation") setOrientation(call.arguments as? String)
            // Time since the tablet was switched on: a fresh start means the
            // Frame tells its managers it runs again (2026-11-05).
            if (call.method == "uptimeMs") {
                result.success(android.os.SystemClock.elapsedRealtime())
                return@setMethodCallHandler
            }
            // Live look from the app (2026-11-18): a video's picture is not
            // in a Flutter screenshot, so the frame at the playing position
            // comes from the file itself (JPEG, at most [width] wide).
            // The live look's screenshot as a small JPEG (sent every 1.5 s).
            if (call.method == "toJpeg") {
                val png = call.arguments as? ByteArray
                Thread {
                    val bytes = try {
                        val bitmap = android.graphics.BitmapFactory.decodeByteArray(png, 0, png?.size ?: 0)
                        if (bitmap == null) null else {
                            val out = java.io.ByteArrayOutputStream()
                            bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 75, out)
                            bitmap.recycle()
                            out.toByteArray()
                        }
                    } catch (e: Exception) { null }
                    runOnUiThread { result.success(bytes) }
                }.start()
                return@setMethodCallHandler
            }
            if (call.method == "videoFrame") {
                val path = call.argument<String>("path")
                val ms = (call.argument<Number>("ms") ?: 0).toLong()
                val width = (call.argument<Number>("width") ?: 640).toInt()
                Thread {
                    val bytes = try { videoFrame(path, ms, width) } catch (e: Exception) { null }
                    runOnUiThread { result.success(bytes) }
                }.start()
                return@setMethodCallHandler
            }
            result.success(null)
        }
        // The app's own slideshow keeps the screen on while it plays
        // (album_slideshow_screen.dart) -- separate from the Frame's window.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smile/screen").setMethodCallHandler { call, result ->
            if (call.method == "keepOn" && !isFrame(this)) {
                if (call.arguments == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
            }
            // The app's slideshow: "Automatisch" turns with the phone even
            // when auto-rotate is off (2026-10-17).
            if (call.method == "orientation") setOrientation(call.arguments as? String)
            result.success(null)
        }
        // Videos are shrunk on the phone before uploading (VideoCompressor).
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smile/video_compress")
        channel.setMethodCallHandler(VideoCompressor(applicationContext, channel))
        // The upload queue asks for (or no longer needs) the background
        // sender (UploadWorker); the worker asks a running app to send.
        val queue = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smile/upload_queue")
        queue.setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> UploadWorker.schedule(applicationContext)
                "cancel" -> UploadWorker.cancel(applicationContext)
            }
            result.success(null)
        }
        queueChannel = queue
        // Album sounds (AlbumSounds.kt): never on a Frame.
        val sounds = AlbumSounds(applicationContext)
        albumSounds = sounds
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smile/sounds").setMethodCallHandler { call, result ->
            if (call.method == "play" && !isFrame(this)) sounds.play(call.arguments as? String)
            result.success(null)
        }
        // Photos and videos shared from other apps (ShareIn.kt).
        val share = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smile/share_in")
        share.setMethodCallHandler { call, result ->
            if (call.method == "take") result.success(ShareIn.take()) else result.notImplemented()
        }
        ShareIn.channel = share
        screenCaptureChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smile/screen_capture")
        // The chime for new photos (FrameChime.kt): only on a Frame.
        val chime = FrameChime(applicationContext)
        frameChime = chime
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smile/frame_chime").setMethodCallHandler { call, result ->
            if (call.method == "play" && isFrame(this)) chime.play()
            result.success(null)
        }
    }

    private var frameChime: FrameChime? = null

    private var albumSounds: AlbumSounds? = null

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        queueChannel = null
        ShareIn.channel = null
        screenCaptureChannel = null
        albumSounds?.release()
        albumSounds = null
        frameChime?.release()
        frameChime = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    companion object {
        /** FrameMode's marker file (getApplicationSupportDirectory = filesDir). */
        fun isFrame(context: Context): Boolean = File(context.filesDir, "frame_mode").exists()

        /** Set while Smile's own Dart code runs (UploadWorker checks it). */
        @Volatile
        var queueChannel: MethodChannel? = null
    }

    /// The home screen shows SmileFrame (own icon) on a Frame and SmileApp
    /// on a phone (2026-10-17): one activity-alias on, the other off. Only
    /// touched when it differs, so the launcher isn't refreshed each start.
    private fun setLauncher(frame: Boolean) {
        val pm = packageManager
        // The aliases' class names stay in the code's package, also in the
        // test app, whose package name has ".test" added.
        val app = ComponentName(this, "com.smile.smile_app.AppLauncher")
        val frameEntry = ComponentName(this, "com.smile.smile_app.FrameLauncher")
        // Sharing to Smile: only on a phone, never on a Frame (2026-11-09).
        val shareTarget = ComponentName(this, "com.smile.smile_app.ShareTarget")
        fun set(component: ComponentName, on: Boolean) {
            val want = if (on) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            val now = pm.getComponentEnabledSetting(component)
            val isOn = now == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                (now == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && component != frameEntry)
            if (isOn != on) pm.setComponentEnabledSetting(component, want, PackageManager.DONT_KILL_APP)
        }
        try {
            // Turn the new one on first: never both off.
            set(if (frame) frameEntry else app, true)
            set(if (frame) app else frameEntry, false)
            set(shareTarget, !frame)
        } catch (_: Exception) {}
    }

    /// sensor: turns with the device by its motion sensor, also when the
    /// system's auto-rotate is off (unlike Flutter's own orientations,
    /// which follow that lock); portrait / landscape: only those, either
    /// way up; anything else: back to the system's rule.
    private fun setOrientation(mode: String?) {
        requestedOrientation = when (mode) {
            "sensor" -> ActivityInfo.SCREEN_ORIENTATION_FULL_SENSOR
            "portrait" -> ActivityInfo.SCREEN_ORIENTATION_SENSOR_PORTRAIT
            "landscape" -> ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
            else -> ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
    }
}
