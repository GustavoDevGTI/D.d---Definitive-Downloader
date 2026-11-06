package br.com.definitivedownloader.app

import android.app.Application
import android.app.NotificationManager
import android.app.Activity
import android.Manifest
import android.content.pm.PackageManager
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Native lifecycle/transport coordination; Dart retains queue policy. */
class AndroidBackgroundChannel(private val app: Application, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "br.com.definitivedownloader/background")
    lateinit var audio: AndroidAudioChannel
    var service: DdWorkService? = null
    var activity: Activity? = null
        set(value) { field = value; if (value != null) timedOut = false }
    private var timedOut = false
    private var requested = false
    var downloading = false; private set
    var paused = false; private set
    var audioReady = false; private set
    var audioEnabled = true; private set
    var playing = false; private set
    var position = 0L; private set
    var duration = 0L; private set
    var title = ""; private set
    var artist = ""; private set
    var downloadTitle = ""; private set
    val mediaActive get() = audioReady && audioEnabled
    val active get() = downloading || mediaActive

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "state" -> {
                        downloading = call.argument<Boolean>("downloading") == true && (!timedOut || activity != null)
                        paused = call.argument<Boolean>("paused") == true
                        audioEnabled = call.argument<Boolean>("audioEnabled") != false
                        title = (call.argument<String>("title") ?: "").take(400)
                        artist = (call.argument<String>("artist") ?: "").take(400)
                        downloadTitle = (call.argument<String>("downloadTitle") ?: "").take(400)
                        synchronize(); result.success(null)
                    }
                    "command" -> { dispatch(call.argument<String>("action") ?: ""); result.success(null) }
                    "status" -> result.success(mapOf("active" to (service != null), "downloading" to downloading,
                        "audioReady" to audioReady, "playing" to playing, "positionMs" to position,
                        "session" to (service?.hasSession == true), "uiAttached" to (activity != null),
                        "paused" to paused, "notifications" to app.getSystemService(NotificationManager::class.java).activeNotifications.count { it.id == 501 || it.id == 502 }))
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                requested = false
                channel.invokeMethod("command", "stopQueue")
                if (::audio.isInitialized) audio.pause()
                result.error("background", "O Android não permitiu manter o trabalho em segundo plano. Abra o app e tente novamente.", null)
            }
        }
    }

    fun audioState(ready: Boolean, audible: Boolean, elapsed: Long, length: Long) {
        val changed = ready != audioReady || audible != playing
        audioReady = ready; playing = audible; position = elapsed; duration = length
        if (changed) synchronize() else service?.timeline()
    }

    private fun synchronize() {
        if (active && !requested) {
            if (Build.VERSION.SDK_INT >= 33 && app.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                val settings = app.getSharedPreferences("dd-permissions", 0)
                val screen = activity
                if (screen != null && !settings.getBoolean("notificationsAsked", false)) {
                    settings.edit().putBoolean("notificationsAsked", true).apply()
                    screen.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4912)
                }
            }
            val intent = Intent(app, DdWorkService::class.java)
            if (Build.VERSION.SDK_INT >= 26) app.startForegroundService(intent) else app.startService(intent)
            requested = true
        }
        service?.refresh()
        if (!active) requested = false
    }

    fun dispatch(action: String) {
        when (action) {
            "play" -> if (audioEnabled) audio.play()
            "pause" -> audio.pause()
            "stopAudio" -> { channel.invokeMethod("command", "stopAudio"); audio.stop() }
            "next", "previous", "pauseQueue", "stopQueue" -> channel.invokeMethod("command", action)
        }
    }

    fun timeout() {
        timedOut = true
        downloading = false
        channel.invokeMethod("command", "stopQueue")
        channel.invokeMethod("command", "stopAudio")
        audio.stop()
        requested = false
    }
    fun detached() { service = null; requested = false }
    fun attached(value: DdWorkService) { service = value; requested = true }
}
