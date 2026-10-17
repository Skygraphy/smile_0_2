package com.smile.smile_app

import android.content.pm.ActivityInfo
import android.content.Context
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
    }

    /**
     * Only while this device is a Frame (FrameMode, 2026-10-11): never let
     * the display sleep and show over the lock screen -- a dedicated
     * display, not a phone.
     */
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
            if (call.method == "setFrameMode") setFrameWindow(call.arguments == true)
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
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        queueChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    companion object {
        /** FrameMode's marker file (getApplicationSupportDirectory = filesDir). */
        fun isFrame(context: Context): Boolean = File(context.filesDir, "frame_mode").exists()

        /** Set while Smile's own Dart code runs (UploadWorker checks it). */
        @Volatile
        var queueChannel: MethodChannel? = null
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
