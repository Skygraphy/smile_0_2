package com.smile.smile_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.io.File

/**
 * After a reboot a Frame should come back by itself (from the former
 * Smile-Frame app) -- but only a device that IS a Frame (FrameMode writes
 * the marker file); a person's phone never starts Smile on boot.
 *
 * Best effort: Android may refuse a start from a receiver (background
 * activity start); a manual re-pin after an unattended reboot is the
 * accepted trade-off (decided 2026-09-11).
 */
class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        if (!MainActivity.isFrame(context)) return
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            context.startActivity(launchIntent)
        } catch (_: Exception) {
        }
    }
}
