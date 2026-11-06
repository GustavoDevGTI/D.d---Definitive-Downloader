package br.com.definitivedownloader.app

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/** Storage stays app-owned; document URIs are never mistaken for filesystem paths. */
class AndroidFilesChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "br.com.definitivedownloader/files")
    private val requestCode = 4910
    private val executor = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var copying = false
    private var kind = ""
    @Volatile private var disposed = false

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "defaultOutput" -> result.success(outputDirectory().path)
                    "chooseOutput" -> chooseOutput(result)
                    "pickFiles" -> pick(call.argument<String>("kind") ?: "", result)
                    "openFile" -> {
                        val file = File(requireNotNull(call.argument<String>("path")))
                        require(file.isFile) { "Arquivo indisponível." }
                        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.files", file)
                        val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(file.extension.lowercase())
                        activity.startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, mime ?: "application/octet-stream")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("storage", "Não foi possível abrir o arquivo ou seletor neste aparelho.", null)
            }
        }
    }

    private fun outputDirectory(): File = File(activity.getExternalFilesDir(null) ?: activity.filesDir, "Definitive Downloader")
        .apply { check(isDirectory || mkdirs()) }

    private fun chooseOutput(result: MethodChannel.Result) {
        val roots = listOf(activity.filesDir) + activity.getExternalFilesDirs(null).filterNotNull()
        val labels = roots.mapIndexed { index, _ -> if (index == 0) "Armazenamento interno do app" else "Mídias do app — volume $index" }
        AlertDialog.Builder(activity).setTitle("Pasta de mídia do app")
            .setItems(labels.toTypedArray()) { _, which ->
                val directory = File(roots[which], "Definitive Downloader")
                if (directory.isDirectory || directory.mkdirs()) result.success(directory.path)
                else result.error("storage", "Pasta indisponível.", null)
            }.setNegativeButton("Cancelar") { _, _ -> result.success(null) }
            .setOnCancelListener { result.success(null) }.show()
    }

    private fun pick(value: String, result: MethodChannel.Result) {
        require(value in listOf("mp3", "csv", "cover"))
        if (pending != null || copying) { result.error("busy", "Aguarde a seleção anterior.", null); return }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
            .setType(when (value) { "mp3" -> "audio/*"; "cover" -> "image/*"; else -> "*/*" })
            .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, value == "mp3")
        kind = value
        pending = result
        try { activity.startActivityForResult(intent, requestCode) }
        catch (error: Exception) { pending = null; throw error }
    }

    fun onActivityResult(request: Int, code: Int, data: Intent?): Boolean {
        if (request != requestCode) return false
        val result = pending ?: return true
        pending = null
        if (code != Activity.RESULT_OK || data == null) { result.success(emptyList<String>()); return true }
        val selectedKind = kind
        copying = true
        val uris = data.clipData?.let { clip -> (0 until clip.itemCount).map { clip.getItemAt(it).uri } }
            ?: listOfNotNull(data.data)
        executor.execute {
            val directory = File(activity.cacheDir, "imports/${UUID.randomUUID()}")
            try {
                require(uris.size <= if (selectedKind == "mp3") 100 else 1)
                check(directory.mkdirs())
                var total = 0L
                val paths = uris.mapIndexed { index, uri ->
                    require(uri.scheme == "content")
                    val original = displayName(uri).replace(Regex("[^\\p{L}\\p{N} ._()\\-]"), "_").take(180)
                    val extension = original.substringAfterLast('.', "").lowercase()
                    require(when (selectedKind) { "mp3" -> extension == "mp3"; "csv" -> extension == "csv"; else -> extension in listOf("png", "jpg", "jpeg", "webp") })
                    val folder = File(directory, index.toString()).apply { check(mkdirs()) }
                    val destination = File(folder, original)
                    val limit = when (selectedKind) { "mp3" -> 200L * 1024 * 1024; "csv" -> 5L * 1024 * 1024; else -> 10L * 1024 * 1024 }
                    var size = 0L
                    activity.contentResolver.openInputStream(uri).use { input ->
                        requireNotNull(input)
                        destination.outputStream().use { output ->
                            val buffer = ByteArray(65536)
                            while (true) {
                                check(!disposed)
                                val read = input.read(buffer)
                                if (read == -1) break
                                size += read; total += read
                                require(size <= limit && total <= 1024L * 1024 * 1024)
                                output.write(buffer, 0, read)
                            }
                        }
                    }
                    require(size > 0)
                    destination.path
                }
                activity.runOnUiThread { copying = false; if (!disposed) result.success(paths) }
            } catch (_: Exception) {
                // Only this adapter-created temporary directory can be removed.
                directory.deleteRecursively()
                activity.runOnUiThread { copying = false; if (!disposed) result.error("import", "Arquivo inválido, indisponível ou acima do limite de importação.", null) }
            }
        }
        return true
    }

    private fun displayName(uri: Uri): String = activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
        .use { cursor -> if (cursor != null && cursor.moveToFirst()) cursor.getString(0) ?: "" else "" }

    fun dispose() {
        disposed = true
        pending?.error("cancelled", "Seleção interrompida.", null); pending = null
        executor.shutdownNow()
        channel.setMethodCallHandler(null)
    }
}
