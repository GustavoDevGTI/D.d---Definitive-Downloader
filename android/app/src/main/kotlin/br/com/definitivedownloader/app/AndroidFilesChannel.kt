package br.com.definitivedownloader.app

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/** Storage stays app-owned; document URIs are never mistaken for filesystem paths. */
class AndroidFilesChannel(private val activity: Activity, messenger: BinaryMessenger, private val documents: ManagedDocumentsChannel) {
    private val folders = AndroidMediaFolders(activity)
    private val destinationPicker = ManagedDocumentsPicker(activity, documents)
    private val channel = MethodChannel(messenger, "br.com.definitivedownloader/files")
    private val requestCode = 4910
    private val executor = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var copying = false
    private var kind = ""
    private val playlistCopies = mutableSetOf<String>()
    @Volatile private var disposed = false

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "defaultOutput" -> result.success(outputDirectory().path)
                    "chooseOutput" -> chooseOutput(result)
                    "pickFiles" -> pick(call.argument<String>("kind") ?: "", result)
                    "releasePlaylistFile" -> {
                        val path = call.argument<String>("path")
                        if (path != null && playlistCopies.remove(path)) deletePlaylistCopy(path)
                        result.success(null)
                    }
                    "openFolder" -> documents.openFolder(activity, requireNotNull(call.argument<String>("path")), result) { path -> folders.open(path, result) }
                    "openFile" -> {
                        documents.openFile(activity, requireNotNull(call.argument<String>("path")), result)
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
        val labels = roots.mapIndexed { index, _ -> if (index == 0) "Armazenamento interno do app" else "Mídias do app — volume $index" } + "Pasta pública ou cartão SD"
        AlertDialog.Builder(activity).setTitle("Pasta de mídia do app")
            .setItems(labels.toTypedArray()) { _, which ->
                if (which == roots.size) { destinationPicker.choose(result); return@setItems }
                val directory = File(roots[which], "Definitive Downloader")
                if (directory.isDirectory || directory.mkdirs()) result.success(directory.path)
                else result.error("storage", "Pasta indisponível.", null)
            }.setNegativeButton("Cancelar") { _, _ -> result.success(null) }
            .setOnCancelListener { result.success(null) }.show()
    }

    private fun pick(value: String, result: MethodChannel.Result) {
        require(value in listOf("mp3", "playlist", "cover"))
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
        if (destinationPicker.onResult(request, code, data)) return true
        if (folders.onActivityResult(request, code, data)) return true
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
                val paths = AndroidDocumentCopies(activity).copy(uris, selectedKind, directory) { disposed }
                activity.runOnUiThread {
                    copying = false
                    if (disposed) {
                        if (selectedKind == "playlist") paths.forEach(::deletePlaylistCopy)
                    } else {
                        if (selectedKind == "playlist") playlistCopies.addAll(paths)
                        result.success(paths)
                    }
                }
            } catch (_: Exception) {
                // Only this adapter-created temporary directory can be removed.
                directory.deleteRecursively()
                activity.runOnUiThread { copying = false; if (!disposed) result.error("import", "Arquivo inválido, indisponível ou acima do limite de importação.", null) }
            }
        }
        return true
    }

    // Only paths returned by this channel's own picker reach this function.
    private fun deletePlaylistCopy(path: String) {
        val file = File(path)
        file.delete()
        file.parentFile?.let { folder ->
            folder.delete()
            folder.parentFile?.delete()
        }
    }

    fun dispose() {
        disposed = true
        folders.dispose()
        destinationPicker.dispose()
        pending?.error("cancelled", "Seleção interrompida.", null); pending = null
        playlistCopies.forEach(::deletePlaylistCopy)
        playlistCopies.clear()
        executor.shutdownNow()
        channel.setMethodCallHandler(null)
    }
}
