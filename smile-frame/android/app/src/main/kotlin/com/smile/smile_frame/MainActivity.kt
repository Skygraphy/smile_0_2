package com.smile.smile_frame

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var kioskLockdown: KioskLockdownPlugin

    override fun onCreate(savedInstanceState: Bundle?) {
        // Must run before super.onCreate(): FlutterActivity's own onCreate
        // already triggers configureFlutterEngine() internally, which
        // reads kioskLockdown -- initializing it after super.onCreate()
        // crashes with UninitializedPropertyAccessException.
        kioskLockdown = KioskLockdownPlugin(this)
        super.onCreate(savedInstanceState)

        // Show the slideshow over the lock screen and never let the
        // display sleep -- this is a dedicated display device, not a
        // regular phone (concept doc sect. 19).
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KioskLockdownPlugin.CHANNEL_NAME)
            .setMethodCallHandler(kioskLockdown)
    }

    // Auto re-pin on resume is deliberately disabled during development
    // (2026-09-07): it turns every app start/relaunch into a Screen-Pinning
    // + Home-role confirmation dance, which made ordinary manual test runs
    // (flutter run/install) unreasonably slow to iterate on. The
    // KioskLockdownPlugin methods (pin/checkStatus/requestHomeRoleIfNeeded)
    // are untouched and ready to be wired back in for Phase 8 hardening --
    // only the automatic on-resume trigger is removed here.
}
