package com.smile.smile_frame

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Screen Pinning does not survive a reboot the way Device-Owner-managed
 * Lock Task does, so the Frame must relaunch itself after boot (concept
 * doc sect. 24, zero-touch operation) -- no user interaction needed, even
 * after a power loss.
 *
 * This direct startActivity() call is a best-effort fallback only, and on
 * its own does NOT reliably work: confirmed live (logcat) that Android's
 * background-activity-start protection aborts it (ActivityTaskManager logs
 * "Background activity start" / callingUidProcState=RECEIVER, result=102 /
 * START_ABORTED), since a BroadcastReceiver has no visible window. The
 * actual reboot-recovery mechanism is holding the Home role (see
 * KioskLockdownPlugin.requestHomeRoleIfNeeded()): a system-initiated Home
 * launch at boot is exempt from this restriction, because the system itself
 * starts the activity rather than our process.
 */
class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(launchIntent)
    }
}
