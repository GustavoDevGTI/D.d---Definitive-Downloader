package br.com.definitivedownloader.app

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import java.io.File
import java.security.MessageDigest
import java.util.UUID

/** Independent public snapshot. Never replaces a pre-existing destination. */
class AndroidPublicExport(private val context: Context) {
    private val journal = AndroidExportJournal(context)
    private val resolver = context.contentResolver

    fun copy(source: File, tree: Uri, cancelled: () -> Boolean): Uri = synchronized(lock) {
        copySnapshot(source, tree, cancelled)
    }
    private fun copySnapshot(source: File, tree: Uri, cancelled: () -> Boolean): Uri {
        require(tree.scheme == "content" && DocumentsContract.isTreeUri(tree))
        val files = snapshot(source)
        check(files.isNotEmpty()) { "A pasta está vazia." }
        val included = files.map { it.canonicalPath }.toSet()
        files.filter { it.extension.lowercase() == "m3u8" }.forEach { playlist ->
            require(playlist.length() <= 5L * 1024 * 1024)
            playlist.useLines { lines -> lines.forEach { line ->
                val reference = line.trim()
                if (reference.isNotEmpty() && !reference.startsWith('#')) {
                    require(!File(reference).isAbsolute && File(playlist.parentFile, reference).canonicalPath in included)
                }
            } }
        }
        val parent = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
        val operation = UUID.randomUUID().toString()
        val folder = DocumentsContract.createDocument(resolver, parent, DocumentsContract.Document.MIME_TYPE_DIR,
            "${source.name.take(100)} - ${operation.take(8)}") ?: error("Pasta indisponível.")
        // Persist the exact new root before creating children. Recovery only addresses this URI.
        try {
            journal.begin(operation, folder)
        } catch (error: Exception) {
            // No children have been created yet. Never recursively delete
            // content another actor might have inserted into this new folder.
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(folder, DocumentsContract.getDocumentId(folder))
            runCatching {
                resolver.query(children, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID), null, null, null).use { cursor ->
                    if (cursor != null && !cursor.moveToFirst()) DocumentsContract.deleteDocument(resolver, folder)
                }
            }
            throw error
        }
        try {
            val directories = mutableMapOf("" to folder)
            val manifests = mutableListOf<Pair<File, Uri>>()
            files.forEach { file ->
                check(!cancelled())
                val relative = file.relativeTo(source)
                var path = ""
                relative.parentFile?.invariantSeparatorsPath?.split('/')?.filter { it.isNotEmpty() }?.forEach { part ->
                    val previous = directories.getValue(path)
                    path = if (path.isEmpty()) part else "$path/$part"
                    if (!directories.containsKey(path)) {
                        val created = DocumentsContract.createDocument(resolver,
                            previous, DocumentsContract.Document.MIME_TYPE_DIR, part) ?: error("Pasta indisponível.")
                        journal.created(operation, created, previous, true)
                        directories[path] = created
                    }
                }
                val target = DocumentsContract.createDocument(resolver, directories.getValue(path),
                    if (file.extension.lowercase() == "mp3") "audio/mpeg" else "application/octet-stream", file.name)
                    ?: error("Não foi possível criar o arquivo.")
                journal.created(operation, target, directories.getValue(path), false)
                // A provider may normalize names; M3U8 references must still name the exact files.
                val name = resolver.query(target, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)
                    .use { cursor -> if (cursor != null && cursor.moveToFirst()) cursor.getString(0) else "" }
                check(name == file.name) { "O destino alterou o nome do arquivo." }
                val size = file.length()
                val modified = file.lastModified()
                val digest = MessageDigest.getInstance("SHA-256")
                var received = 0L
                file.inputStream().use { input ->
                    resolver.openOutputStream(target, "w").use { output ->
                        requireNotNull(output)
                        val buffer = ByteArray(65536)
                        while (true) {
                            check(!cancelled())
                            val read = input.read(buffer)
                            if (read == -1) break
                            received += read
                            check(received <= size)
                            digest.update(buffer, 0, read); output.write(buffer, 0, read)
                        }
                    }
                }
                check(received == size && file.length() == size && file.lastModified() == modified)
                val written = MessageDigest.getInstance("SHA-256")
                var verified = 0L
                resolver.openInputStream(target).use { input ->
                    requireNotNull(input)
                    val buffer = ByteArray(65536)
                    while (true) {
                        check(!cancelled())
                        val read = input.read(buffer)
                        if (read == -1) break
                        verified += read
                        check(verified <= size)
                        written.update(buffer, 0, read)
                    }
                }
                check(verified == size && digest.digest().contentEquals(written.digest())) { "Cópia incompleta." }
                if (file.extension.lowercase() == "m3u8") manifests.add(file to target)
            }
            // Validate what was actually copied, including a manifest replaced
            // concurrently by a just-completed transfer in the private folder.
            manifests.forEach { (file, target) ->
                resolver.openInputStream(target).use { input ->
                    requireNotNull(input)
                    input.bufferedReader(Charsets.UTF_8).useLines { lines -> lines.forEach { line ->
                        val reference = line.trim()
                        if (reference.isNotEmpty() && !reference.startsWith('#')) {
                            require(!File(reference).isAbsolute && File(file.parentFile, reference).canonicalPath in included)
                        }
                    } }
                }
            }
            journal.complete(operation)
            return folder
        } catch (error: Exception) {
            journal.cleanup(operation, folder)
            throw error
        }
    }

    fun recover(): Boolean = synchronized(lock) { journal.recover() }
    fun hasPending(): Boolean = journal.hasPending()

    private fun snapshot(root: File): List<File> {
        require(root.isDirectory && root.canonicalFile == root.absoluteFile)
        var bytes = 0L
        var visited = 0
        val files = mutableListOf<File>()
        fun visit(folder: File, depth: Int) {
            require(depth <= 8)
            val entries = folder.listFiles() ?: error("Pasta indisponível.")
            visited += entries.size
            require(visited <= 12000)
            for (entry in entries.sortedBy { it.name }) {
                // No staging, database, hidden control files or symbolic links.
                if (entry.name.startsWith('.')) continue
                require(entry.canonicalFile == entry.absoluteFile)
                if (entry.isDirectory) visit(entry, depth + 1) else {
                    require(entry.isFile && entry.extension.lowercase() in listOf("mp3", "m3u8"))
                    bytes += entry.length(); files.add(entry)
                    require(files.size <= 10000 && bytes <= 10L * 1024 * 1024 * 1024)
                }
            }
        }
        visit(root, 0)
        return files
    }

    companion object { private val lock = Any() }
}
