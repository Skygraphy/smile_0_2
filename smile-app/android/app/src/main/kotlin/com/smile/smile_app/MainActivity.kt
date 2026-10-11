package com.smile.smile_app

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
}
