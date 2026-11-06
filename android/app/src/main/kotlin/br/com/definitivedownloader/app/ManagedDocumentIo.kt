package br.com.definitivedownloader.app

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract as Docs
import java.io.File
import java.security.MessageDigest

/** Provider access is streamed and performed only on the documents executor. */
internal class ManagedDocumentIo(context: Context) {
    private val resolver = context.contentResolver
    fun children(parent: Uri): Set<String> {
        val uri = Docs.buildChildDocumentsUriUsingTree(parent, Docs.getDocumentId(parent))
        return resolver.query(uri, arrayOf(Docs.Document.COLUMN_DOCUMENT_ID), null, null, null).use { cursor ->
            checkNotNull(cursor)
            buildSet { while (cursor.moveToNext()) { check(size < 10000); add(cursor.getString(0)) } }
        }
    }
    fun present(uri: Uri, parent: Uri): Boolean = Docs.getDocumentId(uri) in children(parent)
    fun create(parent: Uri, mime: String, name: String): Uri {
        val before = children(parent)
        val created = Docs.createDocument(resolver, parent, mime, name) ?: error("Destino indisponível.")
        check(Docs.getDocumentId(created) !in before) { "O provedor reutilizou um documento existente." }
        return created
    }
    fun name(uri: Uri): String = resolver.query(uri, arrayOf(Docs.Document.COLUMN_DISPLAY_NAME), null, null, null).use { cursor ->
        check(cursor != null && cursor.moveToFirst()); cursor.getString(0)
    }
    fun size(uri: Uri): Long? = resolver.query(uri, arrayOf(Docs.Document.COLUMN_SIZE), null, null, null).use { cursor ->
        check(cursor != null && cursor.moveToFirst())
        if (cursor.isNull(0)) null else cursor.getLong(0)
    }
    fun find(parent: Uri, name: String): Uri? {
        val listing = Docs.buildChildDocumentsUriUsingTree(parent, Docs.getDocumentId(parent))
        return resolver.query(listing, arrayOf(Docs.Document.COLUMN_DOCUMENT_ID, Docs.Document.COLUMN_DISPLAY_NAME), null, null, null).use { cursor ->
            checkNotNull(cursor)
            var count = 0
            var result: Uri? = null
            while (cursor.moveToNext()) {
                check(count++ < 10000)
                if (cursor.getString(1) == name) {
                    check(result == null)
                    result = Docs.buildDocumentUriUsingTree(parent, cursor.getString(0))
                }
            }
            result
        }
    }
    fun rename(uri: Uri, name: String): Uri = Docs.renameDocument(resolver, uri, name) ?: error("Não foi possível publicar o nome.")
    fun delete(uri: Uri, parent: Uri) {
        if (present(uri, parent)) check(Docs.deleteDocument(resolver, uri))
    }
    fun fileHash(file: File): String = file.inputStream().use { hash(it, file.length()) }
    fun documentHash(uri: Uri, size: Long): String = resolver.openInputStream(uri).use { input ->
        requireNotNull(input); hash(input, size)
    }
    fun matches(uri: Uri, size: Long, hash: String): Boolean = runCatching { documentHash(uri, size) == hash }.getOrDefault(false)
    private fun hash(input: java.io.InputStream, expected: Long): String {
        require(expected in 1..(500L * 1024 * 1024))
        val digest = MessageDigest.getInstance("SHA-256")
        val bytes = ByteArray(65536)
        var total = 0L
        while (true) {
            val count = input.read(bytes)
            if (count < 0) break
            total += count; check(total <= expected); digest.update(bytes, 0, count)
        }
        check(total == expected)
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
    fun copy(file: File, target: Uri, cancelled: () -> Boolean) {
        val size = file.length(); var count = 0L
        file.inputStream().use { input ->
            resolver.openOutputStream(target, "wt").use { output ->
                requireNotNull(output)
                val bytes = ByteArray(65536)
                while (true) {
                    check(!cancelled())
                    val read = input.read(bytes)
                    if (read < 0) break
                    count += read; check(count <= size); output.write(bytes, 0, read)
                }
            }
        }
        check(count == size && !cancelled())
    }
}
