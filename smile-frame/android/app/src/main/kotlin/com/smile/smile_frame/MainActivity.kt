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

    // Auto re-pin on resume, and the Home-role auto-recovery-after-reboot
    // mechanism, are a deliberate permanent decision (2026-09-11), not a
    // temporary dev convenience: Screen Pinning is triggered manually by
    // whoever sets up a Frame (Android's own Recent-Apps "Pin" gesture --
    // no in-app button needed), and the person can't do anything else on
    // the tablet once pinned regardless of how pinning was triggered, so
    // the automatic path adds no safety benefit. The Home role is a
    // device-wide, hard-to-reverse change (this app becomes the exclusive
    // Android launcher) whose only purpose is surviving an unattended
    // reboot -- not worth the risk for a device that normally just stays
    // powered on; the one time it was tested it coincided with a scary,
    // still-not-fully-explained ADB/USB hang on the test tablet (see
    // kiosk-lockdown-dev-mode memory). If a real need for unattended
    // reboot recovery ever comes up, KioskLockdownPlugin's
    // pin/checkStatus/requestHomeRoleIfNeeded methods are still intact and
    // tested -- only the automatic triggers were ever removed.
}
