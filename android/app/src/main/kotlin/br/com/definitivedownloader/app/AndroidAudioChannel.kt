package br.com.definitivedownloader.app

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** All MediaPlayer operations and callbacks belong to the Android main thread. */
class AndroidAudioChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "br.com.definitivedownloader/audio")
    private val handler = Handler(Looper.getMainLooper())
    private val inspector = Executors.newSingleThreadExecutor()
    private val manager = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
    private var player: MediaPlayer? = null
    private var prepared = false
    private var disposed = false
    private var foreground = true
    private var volume = 0.65f
    private var pending: MethodChannel.Result? = null
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change != AudioManager.AUDIOFOCUS_GAIN) pause()
    }
    private val focusRequest = if (Build.VERSION.SDK_INT >= 26)
        AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN).setAudioAttributes(attributes)
            .setOnAudioFocusChangeListener(focusListener).build() else null
    private val noisy = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) { pause() }
    }
    private val clock = object : Runnable {
        override fun run() {
            if (disposed) return
            runCatching { if (prepared && player?.isPlaying == true) snapshot() }
                .onFailure { prepared = false; snapshot(mapOf("failed" to true)) }
            handler.postDelayed(this, 200)
        }
    }

    init {
        val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if (Build.VERSION.SDK_INT >= 33) activity.registerReceiver(noisy, filter, Context.RECEIVER_NOT_EXPORTED)
        else @Suppress("DEPRECATION") activity.registerReceiver(noisy, filter)
        handler.post(clock)
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "inspect" -> inspect(requireNotNull(call.argument<String>("path")), result)
                    "open" -> open(requireNotNull(call.argument<String>("uri")), result)
                    "play" -> { play(); result.success(null) }
                    "pause" -> { pause(); result.success(null) }
                    "stop" -> { release(); snapshot(); result.success(null) }
                    "seek" -> {
                        if (prepared) {
                            val value = (call.argument<Number>("milliseconds")?.toLong() ?: 0L).coerceAtLeast(0L)
                            if (Build.VERSION.SDK_INT >= 26) player?.seekTo(value, MediaPlayer.SEEK_CLOSEST)
                            else @Suppress("DEPRECATION") player?.seekTo(value.coerceAtMost(Int.MAX_VALUE.toLong()).toInt())
                        }
                        snapshot(); result.success(null)
                    }
                    "volume" -> {
                        volume = (call.argument<Number>("value")?.toFloat() ?: 0.65f).coerceIn(0f, 1f)
                        if (prepared) player?.setVolume(volume, volume)
                        result.success(null)
                    }
                    "dispose" -> { release(); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                if (pending === result) { pending = null; release() }
                result.error("audio", "Não foi possível reproduzir este áudio no Android.", null)
            }
        }
    }

    private fun open(value: String, result: MethodChannel.Result) {
        val uri = Uri.parse(value)
        require(uri.scheme in listOf("file", "https", "http"))
        release()
        val current = MediaPlayer()
        player = current
        pending = result
        current.setAudioAttributes(attributes)
        current.setOnPreparedListener {
            if (player !== current) return@setOnPreparedListener
            prepared = true
            current.setVolume(volume, volume)
            val completion = pending; pending = null
            try { play(); completion?.success(null) }
            catch (_: Exception) { completion?.error("audio", "Áudio indisponível neste momento.", null) }
            handler.post { if (player === current) snapshot() }
        }
        current.setOnCompletionListener {
            if (player === current) snapshot(mapOf("completed" to true))
        }
        current.setOnInfoListener { _, what, _ ->
            if (player === current && what in listOf(MediaPlayer.MEDIA_INFO_BUFFERING_START, MediaPlayer.MEDIA_INFO_BUFFERING_END)) {
                snapshot(mapOf("buffering" to (what == MediaPlayer.MEDIA_INFO_BUFFERING_START)))
            }
            false
        }
        current.setOnErrorListener { _, _, _ ->
            val completion = pending; pending = null
            release()
            completion?.error("audio", "Áudio indisponível ou incompatível.", null)
            snapshot(mapOf("failed" to true))
            true
        }
        if (uri.scheme == "file") current.setDataSource(requireNotNull(uri.path))
        else current.setDataSource(activity, uri)
        current.prepareAsync()
        handler.postDelayed({
            if (player === current && !prepared && pending != null) {
                val completion = pending; pending = null
                release()
                completion?.error("timeout", "O áudio não respondeu no tempo limite.", null)
            }
        }, 30000)
    }

    @Suppress("DEPRECATION")
    private fun play() {
        if (!prepared) return
        if (!foreground) { snapshot(); return }
        val granted = if (Build.VERSION.SDK_INT >= 26) manager.requestAudioFocus(focusRequest!!)
            else manager.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
        check(granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED)
        player?.start()
        snapshot()
    }

    fun pause() {
        runCatching { if (prepared) player?.pause() }.onFailure { release() }
        snapshot()
    }

    fun setForeground(value: Boolean) {
        foreground = value
        if (!value) pause()
    }

    private fun snapshot(extra: Map<String, Any> = emptyMap()) {
        if (disposed) return
        val current = player
        val state = try {
            if (prepared && current != null) mapOf(
                "playing" to current.isPlaying, "positionMs" to current.currentPosition,
                "durationMs" to current.duration) else mapOf("playing" to false)
        } catch (_: IllegalStateException) {
            prepared = false
            mapOf("playing" to false, "failed" to true)
        }
        channel.invokeMethod("event", state + extra)
    }

    @Suppress("DEPRECATION")
    private fun release() {
        prepared = false
        val old = player; player = null
        old?.setOnPreparedListener(null); old?.setOnCompletionListener(null); old?.setOnErrorListener(null); old?.setOnInfoListener(null)
        old?.release()
        pending?.error("cancelled", "Reprodução interrompida.", null); pending = null
        if (Build.VERSION.SDK_INT >= 26) focusRequest?.let { manager.abandonAudioFocusRequest(it) }
        else manager.abandonAudioFocus(focusListener)
    }

    private fun inspect(path: String, result: MethodChannel.Result) {
        inspector.execute {
            val reader = MediaMetadataRetriever()
            try {
                require(File(path).isFile)
                reader.setDataSource(path)
                val duration = reader.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong() ?: 0L
                val mime = reader.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE) ?: ""
                activity.runOnUiThread { result.success(mapOf("durationMs" to duration, "mime" to mime)) }
            } catch (_: Exception) {
                activity.runOnUiThread { result.error("metadata", "Não foi possível conferir este MP3.", null) }
            } finally { runCatching { reader.release() } }
        }
    }

    fun dispose() {
        if (disposed) return
        release()
        disposed = true
        handler.removeCallbacksAndMessages(null)
        inspector.shutdown()
        activity.unregisterReceiver(noisy)
        channel.setMethodCallHandler(null)
    }
}
