package br.com.definitivedownloader.app

import android.app.Activity
import android.app.AlertDialog
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** Browses only app-owned media; SAF export is an explicit independent copy. */
class AndroidMediaFolders(private val activity: Activity) {
    private val executor = Executors.newSingleThreadExecutor()
    private val exporter = AndroidPublicExport(activity.applicationContext)
    private var source: File? = null
    private var dialog: AlertDialog? = null
    @Volatile private var cancelled = false
    @Volatile private var disposed = false
    private val roots get() = (listOf(activity.filesDir) + activity.getExternalFilesDirs(null).filterNotNull())
        .map { File(it, "Definitive Downloader").absoluteFile }

    private fun mediaFolder(path: String): File {
        val folder = File(path).absoluteFile
        require(folder.canonicalFile == folder && folder.isDirectory)
        require(roots.any { folder == it || folder.path.startsWith(it.path + File.separator) })
        return folder
    }

    fun open(path: String, result: MethodChannel.Result) {
        val folder = mediaFolder(path)
        browse(folder)
        result.success(null)
    }

    private fun browse(folder: File) {
        executor.execute {
            val entries = folder.listFiles()?.filter { !it.name.startsWith('.') && it.canonicalFile == it.absoluteFile }
                ?.sortedWith(compareBy<File> { !it.isDirectory }.thenBy { it.name })?.take(10001)
            activity.runOnUiThread {
                if (disposed) return@runOnUiThread
                if (entries == null || entries.size > 10000) { notice("Pasta indisponível ou acima do limite de 10.000 itens."); return@runOnUiThread }
                dialog = AlertDialog.Builder(activity).setTitle(folder.name)
                    .setItems(entries.map { if (it.isDirectory) "▸ ${it.name}" else it.name }.toTypedArray()) { _, index ->
                        val item = entries[index]
                        if (item.isDirectory) browse(mediaFolder(item.path)) else fileActions(item)
                    }
                    .setPositiveButton("Exportar cópia") { _, _ -> confirmExport(folder) }
                    .setNegativeButton("Fechar", null)
                    .apply { if (roots.none { it == folder }) setNeutralButton("Subir") { _, _ -> browse(mediaFolder(folder.parent!!)) } }
                    .show()
            }
        }
    }

    private fun fileActions(file: File) {
        dialog = AlertDialog.Builder(activity).setTitle(file.name).setItems(arrayOf("Abrir", "Compartilhar")) { _, action ->
            try {
                require(file.isFile && file.canonicalFile == file.absoluteFile)
                mediaFolder(file.parent!!)
                val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.files", file)
                val mime = if (file.extension.lowercase() == "mp3") "audio/mpeg" else "audio/x-mpegurl"
                val intent = if (action == 0) Intent(Intent.ACTION_VIEW).setDataAndType(uri, mime)
                else Intent(Intent.ACTION_SEND).setType(mime).putExtra(Intent.EXTRA_STREAM, uri)
                    .apply { clipData = ClipData.newRawUri(file.name, uri) }
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                activity.startActivity(if (action == 0) intent else Intent.createChooser(intent, "Compartilhar arquivo"))
            } catch (_: Exception) { notice("Nenhum aplicativo disponível para abrir ou compartilhar este arquivo.") }
        }.show()
    }

    private fun confirmExport(folder: File) {
        dialog = AlertDialog.Builder(activity).setTitle("Exportar cópia da pasta?")
            .setMessage("MP3 e M3U8 serão copiados para uma nova pasta no destino escolhido. A cópia é independente da biblioteca e permanece após desinstalar o app.")
            .setNegativeButton("Cancelar", null).setPositiveButton("Escolher destino") { _, _ ->
                source = folder
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                    .putExtra(DocumentsContract.EXTRA_INITIAL_URI,
                        DocumentsContract.buildDocumentUri("com.android.externalstorage.documents", "primary:Documents"))
                try { activity.startActivityForResult(intent, REQUEST) }
                catch (_: Exception) { source = null; notice("Seletor de pastas indisponível.") }
            }.show()
    }

    fun onActivityResult(request: Int, code: Int, data: Intent?): Boolean {
        if (request != REQUEST) return false
        val folder = source.also { source = null }
        val uri = data?.data
        if (code != Activity.RESULT_OK || uri == null || folder == null) return true
        try {
            activity.contentResolver.takePersistableUriPermission(uri,
                data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION))
        } catch (_: Exception) { notice("O destino não concedeu acesso persistente. Escolha outra pasta."); return true }
        cancelled = false
        dialog = AlertDialog.Builder(activity).setTitle("Exportando cópia…").setCancelable(false)
            .setNegativeButton("Interromper") { _, _ -> cancelled = true }.show()
        executor.execute {
            val outcome = runCatching {
                check(exporter.recover()) { "Uma exportação interrompida precisa de acesso ao destino anterior para ser removida." }
                exporter.copy(mediaFolder(folder.path), uri) { cancelled || disposed }
            }
            // A completed snapshot needs no standing grant. Retain access only
            // while an exact interrupted-copy journal still needs recovery.
            if (!exporter.hasPending()) runCatching {
                activity.contentResolver.releasePersistableUriPermission(uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            }
            activity.runOnUiThread {
                if (disposed) return@runOnUiThread
                dialog?.dismiss()
                outcome.fold({ target ->
                    dialog = AlertDialog.Builder(activity).setTitle("Cópia exportada")
                        .setNegativeButton("Fechar", null).setPositiveButton("Abrir pasta") { _, _ ->
                            try { activity.startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(target,
                                DocumentsContract.Document.MIME_TYPE_DIR).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)) }
                            catch (_: Exception) { notice("Abra a pasta escolhida no gerenciador de arquivos do aparelho.") }
                        }.show()
                }, { notice(if (cancelled) "Exportação interrompida. A biblioteca foi preservada."
                    else "Não foi possível concluir a cópia. Confira acesso, espaço e disponibilidade do destino. Se a limpeza foi interrompida, selecione novamente o mesmo destino.") })
            }
        }
        return true
    }

    private fun notice(message: String) {
        dialog = AlertDialog.Builder(activity).setMessage(message).setPositiveButton("Fechar", null).show()
    }

    fun dispose() { disposed = true; cancelled = true; dialog?.dismiss(); executor.shutdown() }
    companion object { const val REQUEST = 4911 }
}
