package com.smile.smile_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
        /** Set while Smile's own Dart code runs (UploadWorker checks it). */
        @Volatile
        var queueChannel: MethodChannel? = null
    }
}
