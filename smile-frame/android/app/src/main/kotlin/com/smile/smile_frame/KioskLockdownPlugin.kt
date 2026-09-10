package com.smile.smile_frame

import android.app.ActivityManager
import android.app.AlarmManager
import android.app.PendingIntent
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Screen Pinning (not Device Owner / managed Lock Task via EMM) --
 * startLockTask() is available to any app on API 21+, no factory-reset or
 * managed-provisioning setup required. The first call shows the system's
 * own "Pin this app?" dialog; subsequent calls silently re-pin. Accepted
 * tradeoffs (no remote reboot/wipe, PIN-escapable) are documented in the
 * plan's "Bewusste Abweichungen" section.
 */
class KioskLockdownPlugin(private val activity: MainActivity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL_NAME = "com.smile.frame/kiosk_lockdown"
        private const val HOME_ROLE_REQUEST_CODE = 4201
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pin" -> {
                pinIfNeeded()
                result.success(null)
            }
            "checkStatus" -> result.success(isPinned())
            "restart" -> {
                scheduleRestart()
                result.success(null)
            }
            "requestHomeRoleIfNeeded" -> {
                requestHomeRoleIfNeeded()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * restart_app remote command (concept doc sect. 28): the process
     * can't relaunch itself directly, so this schedules a fresh launch a
     * moment out via AlarmManager, then kills the current process. Mirrors
     * smile_0_1's ComplianceWorker.restart_app handling -- the Dart side
     * reports the command 'completed' *before* calling this, since the
     * process won't survive to report anything afterward.
     */
    private fun scheduleRestart() {
        val restartIntent = Intent(activity, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        }
        val pendingIntent = PendingIntent.getActivity(
            activity,
            0,
            restartIntent,
            PendingIntent.FLAG_CANCEL_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarmManager = activity.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.set(AlarmManager.RTC, System.currentTimeMillis() + 1000, pendingIntent)
        Handler(Looper.getMainLooper()).postDelayed({ Runtime.getRuntime().exit(0) }, 300)
    }

    fun isPinned(): Boolean {
        val activityManager = activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return activityManager.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
    }

    fun pinIfNeeded() {
        if (isPinned()) return
        try {
            activity.startLockTask()
        } catch (_: IllegalArgumentException) {
            // Not available/permitted yet on this device/state -- no-op
            // until the user confirms the system's pin dialog, or the next
            // resume/re-pin attempt succeeds.
        }
    }

    /**
     * Holding the Home role (not Screen Pinning) is what actually makes the
     * Frame reappear on its own after a reboot: a direct startActivity()
     * call from BootCompletedReceiver gets aborted by Android's
     * background-activity-start protection (a BroadcastReceiver has no
     * visible window, so ActivityTaskManager logs "Background activity
     * start" and returns START_ABORTED -- confirmed via logcat on a live
     * device, see BootCompletedReceiver.kt). A system-initiated Home launch
     * at boot is exempt from that restriction entirely, since the system
     * itself -- not our process -- starts the activity.
     *
     * Requesting the role shows the OS's own one-time "Set as Home app?"
     * dialog, same first-run-confirmation pattern as Screen Pinning above.
     * Safe to call on every resume: no-ops immediately if already held or
     * unavailable (API < 29).
     */
    private fun isHomeRoleHeld(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val roleManager = activity.getSystemService(Context.ROLE_SERVICE) as RoleManager
        return roleManager.isRoleHeld(RoleManager.ROLE_HOME)
    }

    private fun requestHomeRoleIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val roleManager = activity.getSystemService(Context.ROLE_SERVICE) as RoleManager
        if (!roleManager.isRoleAvailable(RoleManager.ROLE_HOME)) return
        if (roleManager.isRoleHeld(RoleManager.ROLE_HOME)) return
        val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_HOME)
        activity.startActivityForResult(intent, HOME_ROLE_REQUEST_CODE)
    }
}
