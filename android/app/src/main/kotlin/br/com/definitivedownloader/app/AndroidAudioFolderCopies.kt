package br.com.definitivedownloader.app

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract as Docs
import java.io.File
import java.util.Locale
import java.util.UUID

/** Imports only the tree granted by the system picker, using temporary local copies. */
internal class AndroidAudioFolderCopies(private val context: Context) {
    private companion object {
        const val maxTracks = 10000
        const val maxEntries = 50000
        const val maxAudioBytes = 200L * 1024 * 1024
        const val maxFolderBytes = 1024L * 1024 * 1024
        val extensions = setOf("mp3", "wav", "flac", "m4a", "aac", "ogg", "opus")
        val separators = Regex("[/\\\\\\p{Cc}]")
        val batchName = Regex("[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}")
    }

    private data class Folder(val id: String, val path: String, val depth: Int)
    private data class Audio(val id: String, val path: String, val name: String, val size: Long?)

    private val root: File
        get() = File(context.cacheDir.canonicalFile, "imports/audio-folders")

    fun copy(tree: Uri, cancelled: () -> Boolean): String {
        require(tree.scheme == "content" && Docs.isTreeUri(tree))
        val rootId = Docs.getTreeDocumentId(tree)
        val source = Docs.buildDocumentUriUsingTree(tree, rootId)
        val name = ManagedDocumentIo(context).name(source)
        val tracks = listTracks(tree, rootId, cancelled)
        check(tracks.isNotEmpty()) { "Nenhum áudio compatível nesta pasta." }

        val cache = root
        check(cache.isDirectory || cache.mkdirs())
        val directory = File(cache, UUID.randomUUID().toString())
        check(directory.mkdir()) { "Não foi possível preparar a importação." }
        val playlist = File(directory, safeName(name, "Pasta de áudio"))
        try {
            check(playlist.mkdir())
            val copier = AndroidDocumentCopies(context)
            var remaining = maxFolderBytes
            for ((index, track) in tracks.withIndex()) {
                check(!cancelled())
                val slot = File(playlist, index.toString().padStart(5, '0'))
                check(slot.mkdir())
                val ext = track.name.substringAfterLast('.')
                val stem = safeName(track.name.substringBeforeLast('.'), "Áudio")
                val destination = File(slot, "$stem.$ext")
                val doc = Docs.buildDocumentUriUsingTree(tree, track.id)
                val bytes = copier.copyTo(doc, destination, minOf(remaining, maxAudioBytes), cancelled)
                check(bytes >= 64 && (track.size == null || bytes == track.size)) {
                    "O áudio mudou durante a leitura ou está incompleto."
                }
                remaining -= bytes
            }
            check(!cancelled())
            return playlist.path
        } catch (error: Exception) {
            directory.deleteRecursively()
            throw error
        }
    }

    private fun listTracks(tree: Uri, rootId: String, cancelled: () -> Boolean): List<Audio> {
        val folders = ArrayDeque<Folder>().apply { add(Folder(rootId, "", 0)) }
        val seen = mutableSetOf(rootId)
        val tracks = mutableListOf<Audio>()
        var entries = 0
        var knownBytes = 0L
        val projection = arrayOf(Docs.Document.COLUMN_DOCUMENT_ID, Docs.Document.COLUMN_DISPLAY_NAME,
            Docs.Document.COLUMN_MIME_TYPE, Docs.Document.COLUMN_SIZE)
        while (folders.isNotEmpty()) {
            check(!cancelled())
            val (parentId, parentPath, depth) = folders.removeFirst()
            val children = Docs.buildChildDocumentsUriUsingTree(tree, parentId)
            context.contentResolver.query(children, projection, null, null, null).use { cursor ->
                checkNotNull(cursor) { "Não foi possível ler a pasta selecionada." }
                while (cursor.moveToNext()) {
                    check(!cancelled())
                    check(++entries <= maxEntries) { "A pasta contém itens demais para importar." }
                    val id = cursor.getString(0) ?: continue
                    val name = cursor.getString(1) ?: continue
                    val path = "$parentPath/$name"
                    if (cursor.getString(2) == Docs.Document.MIME_TYPE_DIR) {
                        check(depth < 64) { "A pasta tem subpastas demais." }
                        if (seen.add(id)) folders.add(Folder(id, path, depth + 1))
                    } else if (name.substringAfterLast('.', "").lowercase(Locale.ROOT) in extensions) {
                        val size = if (cursor.isNull(3)) null else cursor.getLong(3).takeIf { it >= 0 }
                        if (size != null) {
                            check(size in 64..maxAudioBytes) { "Áudio inválido ou acima de 200 MB." }
                            knownBytes += size
                            check(knownBytes <= maxFolderBytes) { "A pasta ultrapassa 1 GB de áudio." }
                        }
                        tracks.add(Audio(id, path, name, size))
                        check(tracks.size <= maxTracks) { "Limite de 10.000 faixas por playlist." }
                    }
                }
            }
        }
        return tracks.sortedWith(compareBy({ it.path.lowercase(Locale.ROOT) }, { it.path }, { it.id }))
    }

    fun release(path: String) {
        val playlist = File(path)
        val directory = playlist.parentFile ?: return
        if (directory.parentFile == root && batchName.matches(directory.name) &&
            playlist.isDirectory && playlist.canonicalFile == playlist &&
            directory.canonicalFile == directory) {
            directory.deleteRecursively()
        }
    }

    private fun safeName(name: String, fallback: String): String =
        name.replace(separators, "_").trim().take(160)
            .takeUnless { it.isEmpty() || it == "." || it == ".." } ?: fallback
}
