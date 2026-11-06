package br.com.definitivedownloader.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager

/** Active work only, no boot receiver or automatic restart/re-download. */
class DdWorkService : Service() {
    private val host get() = (application as DdApplication).runtime.background
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var session: MediaSession
    private var wake: PowerManager.WakeLock? = null
    private var lastTimeline = 0L
    private val idle = Runnable { if (!host.playing && !host.downloading) { stopForeground(STOP_FOREGROUND_DETACH); stopSelf() } }
    val hasSession get() = ::session.isInitialized && session.isActive
    private val renew = object : Runnable {
        override fun run() {
            if (host.downloading) {
                wake?.acquire(120000)
                handler.postDelayed(this, 60000)
            }
        }
    }
    override fun onCreate() {
        super.onCreate()
        host.attached(this)
        if (Build.VERSION.SDK_INT >= 26) {
            val notifications = getSystemService(NotificationManager::class.java)
            notifications.createNotificationChannel(NotificationChannel("dd-active", "Downloads e reprodução", NotificationManager.IMPORTANCE_LOW))
        }
        wake = (getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$packageName:downloads").apply { setReferenceCounted(false) }
        session = MediaSession(this, "D.d").apply {
            setSessionActivity(openApp())
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() = host.dispatch("play")
                override fun onPause() = host.dispatch("pause")
                override fun onStop() = host.dispatch("stopAudio")
                override fun onSkipToNext() = host.dispatch("next")
                override fun onSkipToPrevious() = host.dispatch("previous")
                override fun onSeekTo(pos: Long) = (application as DdApplication).runtime.audio.seek(pos)
            })
        }
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        refresh()
        if (intent?.action != null) host.dispatch(intent.action!!)
        refresh()
        return START_NOT_STICKY
    }
    private fun openApp(): PendingIntent = PendingIntent.getActivity(this, 0,
        Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun action(name: String, icon: Int, label: String): Notification.Action = Notification.Action.Builder(icon, label,
        PendingIntent.getService(this, name.hashCode(), Intent(this, DdWorkService::class.java).setAction(name), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)).build()

    fun refresh() {
        if (!host.active) {
            getSystemService(NotificationManager::class.java).cancel(502)
            stopForeground(STOP_FOREGROUND_REMOVE); stopSelf(); return
        }
        var types = 0
        if (host.downloading) types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
        if (host.mediaActive) types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "dd-active") else @Suppress("DEPRECATION") Notification.Builder(this)
        builder.setSmallIcon(android.R.drawable.stat_sys_download).setContentIntent(openApp())
            .setShowWhen(false).setOnlyAlertOnce(true).setOngoing(host.playing || host.downloading)
            .setContentTitle(if (host.mediaActive) host.title.ifEmpty { "Definitive Downloader" } else "Downloads")
            .setContentText(if (host.mediaActive) host.artist else host.downloadTitle)
        if (host.mediaActive) {
            builder.addAction(action("previous", android.R.drawable.ic_media_previous, "Anterior"))
            builder.addAction(action(if (host.playing) "pause" else "play", if (host.playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play, if (host.playing) "Pausar" else "Reproduzir"))
            builder.addAction(action("next", android.R.drawable.ic_media_next, "Próxima"))
            builder.addAction(action("stopAudio", android.R.drawable.ic_menu_close_clear_cancel, "Fechar player"))
            builder.setStyle(Notification.MediaStyle().setMediaSession(session.sessionToken).setShowActionsInCompactView(0, 1, 2))
        }
        if (host.downloading && !host.mediaActive) {
            builder.addAction(action("pauseQueue", android.R.drawable.ic_media_pause, if (host.paused) "Retomar fila" else "Pausar fila"))
            builder.addAction(action("stopQueue", android.R.drawable.ic_menu_close_clear_cancel, "Parar downloads"))
        }
        val notification = builder.build()
        if (Build.VERSION.SDK_INT >= 29) startForeground(501, notification, types) else startForeground(501, notification)
        val notifications = getSystemService(NotificationManager::class.java)
        if (host.downloading && host.mediaActive) {
            val downloads = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "dd-active") else @Suppress("DEPRECATION") Notification.Builder(this)
            downloads.setSmallIcon(android.R.drawable.stat_sys_download).setContentTitle(if (host.paused) "Fila pausada" else "Downloads")
                .setContentText(host.downloadTitle).setContentIntent(openApp()).setOnlyAlertOnce(true).setShowWhen(false).setOngoing(true)
                .addAction(action("pauseQueue", android.R.drawable.ic_media_pause, if (host.paused) "Retomar fila" else "Pausar fila"))
                .addAction(action("stopQueue", android.R.drawable.ic_menu_close_clear_cancel, "Parar downloads"))
            notifications.notify(502, downloads.build())
        } else notifications.cancel(502)
        session.isActive = host.mediaActive
        session.setMetadata(MediaMetadata.Builder().putString(MediaMetadata.METADATA_KEY_TITLE, host.title)
            .putString(MediaMetadata.METADATA_KEY_ARTIST, host.artist).putLong(MediaMetadata.METADATA_KEY_DURATION, host.duration).build())
        timeline(true)
        handler.removeCallbacks(renew)
        if (host.downloading) handler.post(renew) else if (wake?.isHeld == true) wake?.release()
        handler.removeCallbacks(idle)
        if (!host.playing && !host.downloading) handler.postDelayed(idle, 600000)
    }
    fun timeline(force: Boolean = false) {
        val now = android.os.SystemClock.elapsedRealtime()
        if (!force && now - lastTimeline < 1000) return
        lastTimeline = now
        session.setPlaybackState(PlaybackState.Builder().setActions(PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_PLAY_PAUSE or PlaybackState.ACTION_SKIP_TO_NEXT or PlaybackState.ACTION_SKIP_TO_PREVIOUS or PlaybackState.ACTION_SEEK_TO or PlaybackState.ACTION_STOP)
            .setState(if (host.playing) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED, host.position, if (host.playing) 1f else 0f).build())
    }
    override fun onTimeout(startId: Int, fgsType: Int) { host.timeout(); stopForeground(STOP_FOREGROUND_REMOVE); stopSelf() }
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        if (wake?.isHeld == true) wake?.release()
        session.release()
        getSystemService(NotificationManager::class.java).cancel(502)
        host.detached()
        super.onDestroy()
    }
}
