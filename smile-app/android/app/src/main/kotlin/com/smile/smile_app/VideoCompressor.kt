package com.smile.smile_app

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.AudioEncoderSettings
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Shrinks a video on the phone before it is uploaded, like WhatsApp
 * (decided 2026-10-09): the same profile the media-processing-service
 * produces anyway -- shorter edge at most 720 px (720p, either way round), H.264, about 1.8 Mbit/s,
 * HDR tone-mapped to SDR -- so a minute of S26 video is ~20 MB instead of
 * 100-700 MB. Uses the phone's hardware encoder (Media3 Transformer).
 *
 * Channel "smile/video_compress": compress {input, output} -> output path;
 * while it runs, "progress" (0-100) is sent back to Dart.
 */
private const val TARGET_SHORT_SIDE = 720

/** The video's shorter edge in pixels (rotation doesn't change it). */
private fun shortSideOf(path: String): Int? {
    val retriever = MediaMetadataRetriever()
    return try {
        retriever.setDataSource(path)
        val w = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull()
        val h = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull()
        if (w == null || h == null) null else minOf(w, h)
    } catch (e: Exception) {
        null
    } finally {
        retriever.release()
    }
}

/** Width and height as the video is shown, i.e. with its rotation applied. */
private fun displaySizeOf(path: String): Pair<Int, Int>? {
    val retriever = MediaMetadataRetriever()
    return try {
        retriever.setDataSource(path)
        val w = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull()
        val h = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull()
        val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
        if (w == null || h == null) null else if (rotation % 180 != 0) Pair(h, w) else Pair(w, h)
    } catch (e: Exception) {
        null
    } finally {
        retriever.release()
    }
}

class VideoCompressor(private val context: Context, private val channel: MethodChannel) :
    MethodChannel.MethodCallHandler {

    private val main = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "compress") {
            result.notImplemented()
            return
        }
        val input = call.argument<String>("input")
        val output = call.argument<String>("output")
        if (input == null || output == null) {
            result.error("bad_arguments", "input and output are required", null)
            return
        }
        // The person's choice "Videos senden" (2026-10-12, video_quality.dart).
        val shortSide = call.argument<Int>("shortSide") ?: TARGET_SHORT_SIDE
        val bitrate = call.argument<Int>("bitrate") ?: 1_800_000
        val audioBitrate = call.argument<Int>("audioBitrate") ?: 128_000
        compress(input, output, shortSide, bitrate, audioBitrate, result)
    }

    private fun compress(
        input: String,
        output: String,
        targetShortSide: Int,
        bitrate: Int,
        audioBitrate: Int,
        result: MethodChannel.Result,
    ) {
        var finished = false
        lateinit var transformer: Transformer
        val progressHolder = ProgressHolder()
        val reportProgress = object : Runnable {
            override fun run() {
                if (finished) return
                if (transformer.getProgress(progressHolder) == Transformer.PROGRESS_STATE_AVAILABLE) {
                    channel.invokeMethod("progress", progressHolder.progress)
                }
                main.postDelayed(this, 500)
            }
        }

        transformer = Transformer.Builder(context)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(
                DefaultEncoderFactory.Builder(context)
                    .setRequestedVideoEncoderSettings(
                        VideoEncoderSettings.Builder().setBitrate(bitrate).build()
                    )
                    .setRequestedAudioEncoderSettings(
                        AudioEncoderSettings.Builder().setBitrate(audioBitrate).build()
                    )
                    .build()
            )
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    finished = true
                    Log.i("SmileVideo", "compressed to ${File(output).length()} bytes, ${exportResult.durationMs} ms video")
                    // As shown, not as stored: a phone video is often kept as
                    // landscape pixels plus "rotate 90" -- ExportResult reports
                    // the stored size, which made portrait videos show as
                    // landscape (found 2026-10-09).
                    val (width, height) = displaySizeOf(output) ?: Pair(exportResult.width, exportResult.height)
                    result.success(
                        mapOf(
                            "path" to output,
                            "width" to width,
                            "height" to height,
                            "durationMs" to exportResult.durationMs,
                        )
                    )
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException,
                ) {
                    finished = true
                    File(output).delete()
                    Log.e("SmileVideo", "compress failed: ${exportException.errorCodeName}", exportException)
                    result.error("compress_failed", exportException.message, null)
                }
            })
            .build()

        // The SHORT side to 720 px keeps the shape (portrait 720x1280,
        // landscape 1280x720). "Fit into 1280x1280" made every video a
        // letterboxed square (found 2026-10-09). Smaller videos stay as
        // they are -- never scaled up.
        val shortSide = shortSideOf(input)
        val effects = if (shortSide != null && shortSide > targetShortSide) {
            Effects(listOf(), listOf(Presentation.createForShortSide(targetShortSide)))
        } else {
            Effects.EMPTY
        }
        val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(input))))
            .setEffects(effects)
            .build()
        val composition = Composition.Builder(EditedMediaItemSequence.Builder(listOf(item)).build())
            .setHdrMode(Composition.HDR_MODE_TONE_MAP_HDR_TO_SDR_USING_OPEN_GL)
            .build()

        transformer.start(composition, output)
        main.postDelayed(reportProgress, 500)
    }
}
