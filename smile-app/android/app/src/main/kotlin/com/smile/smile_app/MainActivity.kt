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
    }
}
