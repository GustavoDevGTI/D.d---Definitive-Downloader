package br.com.definitivedownloader.app

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import android.system.Os
import java.util.Collections

/** Provider policy is in the shared core; this module owns Android execution. */
class AndroidMusicChannel(context: Context, messenger: BinaryMessenger) {
    private val app = context.applicationContext
    private val channel = MethodChannel(messenger, "br.com.definitivedownloader/music")
    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newFixedThreadPool(2)
    private val controls = Executors.newSingleThreadExecutor()
    private val jobs = ConcurrentHashMap<String, AndroidMusicProcess>()
    private val cancelledGroups = Collections.synchronizedSet(LinkedHashSet<Int>())
    @Volatile private var disposed = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (disposed) { result.error("closed", "Motor musical encerrado.", null); return@setMethodCallHandler }
            when (call.method) {
                "run" -> {
                    val id = call.argument<String>("id") ?: ""
                    val payload = call.argument<String>("request") ?: ""
                    if (!id.matches(Regex("[A-Za-z0-9-]{1,80}")) || payload.toByteArray().size > 32768 || jobs.size >= 4) {
                        result.error("request", "Requisição musical inválida ou motor ocupado.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val operation = JSONObject(payload).getString("operation")
                        require(operation in listOf("health", "search", "download", "deezerConnect"))
                    } catch (_: Exception) {
                        result.error("request", "Operação musical inválida.", null)
                        return@setMethodCallHandler
                    }
                    val job = AndroidMusicProcess(app, payload) { line -> main.post {
                        if (!disposed) channel.invokeMethod("event", mapOf("id" to id, "line" to line))
                    } }
                    if (jobs.putIfAbsent(id, job) != null) {
                        result.error("busy", "Operação musical já existente.", null)
                        return@setMethodCallHandler
                    }
                    executor.execute {
                        try {
                            val response = job.execute()
                            main.post { if (!disposed) result.success(response) }
                        } catch (error: Exception) {
                            val safe = if (error is MusicRuntimeFailure) error.safeMessage
                                else "O motor musical Android não concluiu a operação."
                            main.post { if (!disposed) result.error("music", safe, null) }
                        } finally {
                            if (job.wasCancelled && job.ownedGroup > 1) synchronized(cancelledGroups) {
                                if (cancelledGroups.size >= 8) cancelledGroups.remove(cancelledGroups.first())
                                cancelledGroups.add(job.ownedGroup)
                            }
                            jobs.remove(id, job)
                        }
                    }
                }
                "control" -> {
                    val id = call.argument<String>("id") ?: ""
                    val job = jobs[id]
                    if (job == null) { result.success(null); return@setMethodCallHandler }
                    val control = call.argument<String>("control")
                    val paused = call.argument<Boolean>("enabled") ?: false
                    controls.execute { if (control == "cancel") job.cancel() else if (control == "pause") job.pause(paused) }
                    result.success(null)
                }
                "status" -> {
                    val alive = synchronized(cancelledGroups) {
                        cancelledGroups.count { group -> runCatching { Os.kill(-group, 0) }.isSuccess }
                    }
                    result.success(mapOf("active" to jobs.size, "cancelledGroupsAlive" to alive))
                }
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        disposed = true
        jobs.values.forEach { it.cancel() }
        executor.shutdownNow()
        controls.shutdownNow()
        channel.setMethodCallHandler(null)
        main.removeCallbacksAndMessages(null)
    }
}
