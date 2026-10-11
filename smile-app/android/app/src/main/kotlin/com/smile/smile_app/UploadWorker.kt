package com.smile.smile_app

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import java.util.concurrent.TimeUnit

/**
 * Sends the photos and videos still waiting in the upload queue
 * (upload_queue.dart) as soon as there is a connection -- also when Smile
 * is closed, like WhatsApp does with messages written offline (decided
 * 2026-10-11).
 *
 * If Smile is running, it is only asked to send (one sender at a time);
 * otherwise this starts the app's Dart code without a screen
 * (uploadQueueWorker in main.dart) and waits until it is done.
 */
class UploadWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        if (!hasWaitingItems(applicationContext)) return Result.success()
        val app = MainActivity.queueChannel
        if (app != null) {
            withContext(Dispatchers.Main) { app.invokeMethod("process", null) }
            // Again later, in case Smile is closed before it is done.
            return Result.retry()
        }
        val (engine, finished) = withContext(Dispatchers.Main) { startEngine() }
        val left = try {
            withTimeoutOrNull(9 * 60 * 1000L) { finished.await() }
        } finally {
            withContext(Dispatchers.Main) { engine.destroy() }
        }
        return if (left == 0 || !hasWaitingItems(applicationContext)) Result.success() else Result.retry()
    }

    private fun startEngine(): Pair<FlutterEngine, CompletableDeferred<Int>> {
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)
        // Registers the app's plugins itself (supabase, path_provider, ...).
        val engine = FlutterEngine(applicationContext)
        val messenger = engine.dartExecutor.binaryMessenger
        val video = MethodChannel(messenger, "smile/video_compress")
        video.setMethodCallHandler(VideoCompressor(applicationContext, video))
        val finished = CompletableDeferred<Int>()
        MethodChannel(messenger, "smile/upload_queue").setMethodCallHandler { call, result ->
            if (call.method == "finished") finished.complete((call.arguments as? Int) ?: 1)
            result.success(null)
        }
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "uploadQueueWorker"),
        )
        return engine to finished
    }

    companion object {
        private const val NAME = "smile_upload_queue"

        /** Same folder as upload_queue.dart (getApplicationSupportDirectory). */
        fun hasWaitingItems(context: Context): Boolean =
            File(context.filesDir, "upload_queue").listFiles()?.any { File(it, "meta.json").exists() } == true

        fun schedule(context: Context) {
            val request = OneTimeWorkRequestBuilder<UploadWorker>()
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                // While Smile is open it sends itself; this is the safety net.
                .setInitialDelay(15, TimeUnit.SECONDS)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(NAME, ExistingWorkPolicy.KEEP, request)
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(NAME)
        }
    }
}
