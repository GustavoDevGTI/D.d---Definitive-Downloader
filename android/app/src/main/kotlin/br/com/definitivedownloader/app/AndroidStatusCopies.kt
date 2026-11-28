package br.com.definitivedownloader.app

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract as Docs
import java.io.File
import java.util.Locale
import java.util.UUID

/**
 * Status Saver: copies the WhatsApp statuses of the tree granted by the system
 * picker into the app cache. WhatsApp's files are only read; the permission is
 * not persisted and nothing outside the granted tree is listed.
 */
internal class AndroidStatusCopies(private val context: Context) {
    companion object {
        const val maxItems = 200
        const val maxEntries = 2000
        const val maxItemBytes = 200L * 1024 * 1024
        const val maxTotalBytes = 2048L * 1024 * 1024
        val extensions = setOf("mp4", "3gp", "mkv", "webm", "opus", "ogg", "m4a", "aac", "mp3")
        private val separators = Regex("[/\\\\\\p{Cc}]")
        private val batchName = Regex("[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}")

        /** Where the system picker opens: the regular WhatsApp status folder. */
        fun initialUri(): Uri = Docs.buildDocumentUri(
            "com.android.externalstorage.documents",
            "primary:Android/media/com.whatsapp/WhatsApp/Media/.Statuses")
    }

    private data class Status(val id: String, val name: String, val size: Long?, val modified: Long?)

    private val root: File
        get() = File(context.cacheDir.canonicalFile, "imports/whatsapp-statuses")

    fun copy(tree: Uri, cancelled: () -> Boolean): String {
        require(tree.scheme == "content" && Docs.isTreeUri(tree))
        val treeRoot = Docs.getTreeDocumentId(tree)
        // A parent folder (WhatsApp/Media) may be chosen; use its .Statuses.
        val folder = child(tree, treeRoot, ".Statuses") ?: treeRoot
        val statuses = list(tree, folder, cancelled)
        check(statuses.isNotEmpty()) { "Nenhum status de vídeo ou áudio nesta pasta." }
        val cache = root
        check(cache.isDirectory || cache.mkdirs())
        val directory = File(cache, UUID.randomUUID().toString())
        check(directory.mkdir()) { "Não foi possível preparar a leitura dos status." }
        try {
            val copier = AndroidDocumentCopies(context)
            var remaining = maxTotalBytes
            for ((index, status) in statuses.withIndex()) {
                check(!cancelled())
                val ext = status.name.substringAfterLast('.').lowercase(Locale.ROOT)
                val stem = safeName(status.name.substringBeforeLast('.'))
                val destination = File(directory, "${index.toString().padStart(3, '0')}-$stem.$ext")
                val doc = Docs.buildDocumentUriUsingTree(tree, status.id)
                val bytes = copier.copyTo(doc, destination, minOf(remaining, maxItemBytes), cancelled)
                check(bytes >= 1024 && (status.size == null || bytes == status.size)) {
                    "Um status mudou durante a leitura ou está incompleto."
                }
                status.modified?.let { destination.setLastModified(it) }
                remaining -= bytes
            }
            check(!cancelled())
            return directory.path
        } catch (error: Exception) {
            directory.deleteRecursively()
            throw error
        }
    }

    private fun child(tree: Uri, parent: String, name: String): String? {
        val projection = arrayOf(Docs.Document.COLUMN_DOCUMENT_ID, Docs.Document.COLUMN_DISPLAY_NAME,
            Docs.Document.COLUMN_MIME_TYPE)
        context.contentResolver.query(Docs.buildChildDocumentsUriUsingTree(tree, parent),
            projection, null, null, null).use { cursor ->
            checkNotNull(cursor) { "Não foi possível ler a pasta selecionada." }
            var entries = 0
            while (cursor.moveToNext()) {
                check(++entries <= maxEntries) { "A pasta contém itens demais." }
                if (cursor.getString(1) == name && cursor.getString(2) == Docs.Document.MIME_TYPE_DIR) {
                    return cursor.getString(0)
                }
            }
        }
        return null
    }

    // Statuses sit directly in the folder; subfolders are not visited.
    private fun list(tree: Uri, folder: String, cancelled: () -> Boolean): List<Status> {
        val projection = arrayOf(Docs.Document.COLUMN_DOCUMENT_ID, Docs.Document.COLUMN_DISPLAY_NAME,
            Docs.Document.COLUMN_MIME_TYPE, Docs.Document.COLUMN_SIZE, Docs.Document.COLUMN_LAST_MODIFIED)
        val statuses = mutableListOf<Status>()
        var entries = 0
        var knownBytes = 0L
        context.contentResolver.query(Docs.buildChildDocumentsUriUsingTree(tree, folder),
            projection, null, null, null).use { cursor ->
            checkNotNull(cursor) { "Não foi possível ler a pasta selecionada." }
            while (cursor.moveToNext()) {
                check(!cancelled())
                check(++entries <= maxEntries) { "A pasta contém itens demais." }
                val id = cursor.getString(0) ?: continue
                val name = cursor.getString(1) ?: continue
                if (cursor.getString(2) == Docs.Document.MIME_TYPE_DIR) continue
                if (name.substringAfterLast('.', "").lowercase(Locale.ROOT) !in extensions) continue
                val size = if (cursor.isNull(3)) null else cursor.getLong(3).takeIf { it >= 0 }
                if (size != null) {
                    if (size !in 1024..maxItemBytes) continue
                    knownBytes += size
                    check(knownBytes <= maxTotalBytes) { "Os status ultrapassam 2 GB." }
                }
                val modified = if (cursor.isNull(4)) null else cursor.getLong(4).takeIf { it > 0 }
                statuses.add(Status(id, name, size, modified))
                check(statuses.size <= maxItems) { "Há status demais nesta pasta." }
            }
        }
        // Newest first, as WhatsApp shows them.
        return statuses.sortedWith(compareByDescending<Status> { it.modified ?: 0L }.thenBy { it.name })
    }

    fun release(path: String) {
        val directory = File(path)
        if (directory.parentFile == root && batchName.matches(directory.name) &&
            directory.isDirectory && directory.canonicalFile == directory) {
            directory.deleteRecursively()
        }
    }

    private fun safeName(name: String): String =
        name.replace(separators, "_").trim().take(120)
            .takeUnless { it.isEmpty() || it == "." || it == ".." } ?: "status"
}
