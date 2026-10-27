package com.smile.smile_app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool

/**
 * Smile's own short album sounds (2026-10-27, like WhatsApp's chat tones):
 * "send" when photos/videos have been sent, "receive" when someone else's
 * arrive in the album that is open. Both are generated, not copied
 * (tools/sounds/make.js, make2.js). Quiet whenever the phone is on silent or vibrate.
 */
class AlbumSounds(context: Context) {
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val pool = SoundPool.Builder()
        .setMaxStreams(2)
        .setAudioAttributes(
            AudioAttributes.Builder()
                // The notification volume, like WhatsApp's chat tones -- the
                // system volume is often at 0 (S26, 2026-10-27: nothing heard).
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_COMMUNICATION_INSTANT)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        .build()
    private val send = pool.load(context, R.raw.smile_send, 1)
    private val receive = pool.load(context, R.raw.smile_receive, 1)

    fun play(name: String?) {
        if (audio.ringerMode != AudioManager.RINGER_MODE_NORMAL) return
        val id = when (name) {
            "send" -> send
            "receive" -> receive
            else -> return
        }
        pool.play(id, 1f, 1f, 1, 0, 1f)
    }

    fun release() = pool.release()
}
