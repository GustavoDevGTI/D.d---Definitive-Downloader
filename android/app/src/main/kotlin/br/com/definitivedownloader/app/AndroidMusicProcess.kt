package br.com.definitivedownloader.app

import android.content.Context
import android.system.Os
import android.system.OsConstants
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID

class MusicRuntimeFailure(val safeMessage: String) : Exception()

/** One private pipe, one nonce-confirmed process group, no shell or global scan. */
class AndroidMusicProcess(private val context: Context, private val payload: String,
    private val event: (String) -> Unit) {
    private val nonce = UUID.randomUUID().toString()
    @Volatile private var process: Process? = null
    @Volatile private var group = 0
    @Volatile private var cancelled = false
    @Volatile private var paused = false
    private val inputLock = Any()
    val ownedGroup: Int get() = group
    val wasCancelled: Boolean get() = cancelled

    fun pause(value: Boolean) {
        paused = value
        if (group != 0) synchronized(inputLock) {
            runCatching { process?.outputStream?.let {
                it.write((JSONObject(mapOf("control" to "pause", "enabled" to value)).toString() + "\n").toByteArray())
                it.flush()
            } }
        }
    }

    fun cancel() {
        cancelled = true
        val owned = process ?: return
        // The group remains ours while descendants exist, even if Python exited.
        // Drop the Process reference at job completion so late controls do nothing.
        if (group > 1) runCatching { Os.kill(-group, OsConstants.SIGKILL) }
        // Before the ownership handshake, the bootstrap waits without children.
        owned.destroy()
    }

    fun execute(): String {
        val installation = AndroidMusicAssets.prepare(context)
        checkCancelled()
        val request = JSONObject(payload)
        val download = request.optString("operation") == "download"
        if (download) verifyStaging(request.getString("directory"))
        if (request.optString("operation") == "extractAudio") {
            verifyStaging(request.getString("directory"))
            verifyStatusCopy(request.getString("path"))
        }
        val temp = File(context.cacheDir, "dd-native-jobs/$nonce").apply { check(mkdirs()) }
        var reader: Thread? = null
        try {
            val builder = ProcessBuilder(installation.python.path, "-u", File(installation.bundle, "entry.py").path)
            builder.directory(installation.bundle)
            builder.environment().putAll(installation.environment)
            builder.environment()["DD_JOB_NONCE"] = nonce
            builder.environment()["TMPDIR"] = temp.path
            val child = builder.start()
            process = child
            if (cancelled) cancel()
            // Drain stderr without storing/logging credentials, URLs or banners.
            reader = Thread({ runCatching { child.errorStream.use { stream ->
                val buffer = ByteArray(8192)
                while (stream.read(buffer) >= 0) { /* bounded working memory */ }
            } } }, "dd-music-stderr").apply { isDaemon = true; start() }
            var total = 0
            var result: String? = null
            var failure: String? = null
            child.inputStream.buffered().use { stream ->
                val line = ByteArrayOutputStream()
                while (true) {
                    val byte = stream.read()
                    if (byte < 0) break
                    check(++total <= 2 * 1024 * 1024)
                    if (byte != 10) {
                        check(line.size() < 32768)
                        line.write(byte)
                        continue
                    }
                    if (line.size() == 0) continue
                    val text = line.toString("UTF-8"); line.reset()
                    val message = JSONObject(text)
                    when (message.optString("event")) {
                        "started" -> {
                            require(group == 0 && message.getString("nonce") == nonce)
                            val pid = message.getInt("pid")
                            require(pid > 1 && pid == message.getInt("group"))
                            group = pid
                            checkCancelled()
                            synchronized(inputLock) {
                                child.outputStream.write((JSONObject(mapOf("start" to nonce)).toString() + "\n" + payload + "\n").toByteArray())
                                child.outputStream.flush()
                                if (!download) child.outputStream.close()
                            }
                            if (download && paused) pause(true)
                        }
                        "stage", "progress" -> { require(group > 1); event(text) }
                        "result" -> { require(group > 1 && result == null); result = message.getJSONObject("result").toString() }
                        "error" -> { failure = message.optString("message").takeIf { it.length in 1..300 } }
                    }
                }
            }
            val code = child.waitFor()
            reader.join(1000)
            checkCancelled()
            if (failure != null) throw MusicRuntimeFailure(failure!!)
            if (code != 0 || result == null) throw MusicRuntimeFailure("O motor musical Android não concluiu a operação.")
            return result!!
        } catch (error: Exception) {
            cancel()
            throw error
        } finally {
            runCatching { process?.outputStream?.close() }
            process = null
            // This UUID directory contains runtime temporaries, never final media.
            temp.deleteRecursively()
        }
    }

    private fun checkCancelled() { if (cancelled) throw MusicRuntimeFailure("Operação musical interrompida.") }

    // Status Saver extracts audio only from the app's own copies of the statuses.
    private fun verifyStatusCopy(path: String) {
        val file = File(path).canonicalFile
        val root = File(context.cacheDir, "imports/whatsapp-statuses").canonicalFile
        require(file.isFile && file.path.startsWith(root.path + File.separator))
        require(file.length() in 1024..AndroidStatusCopies.maxItemBytes)
    }

    private fun verifyStaging(path: String) {
        val directory = File(path).canonicalFile
        val roots = listOf(context.cacheDir, context.filesDir) + context.getExternalFilesDirs(null).filterNotNull()
        require(roots.any { directory.path.startsWith(it.canonicalPath + File.separator) })
        require(directory.isDirectory && directory.listFiles()?.isEmpty() == true)
    }
}
