package br.com.definitivedownloader.app

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File

/** The same bounded, read-only document import serves the picker and Sharesheet. */
class AndroidDocumentCopies(private val context: Context) {
    fun copy(uris: List<Uri>, kind: String, directory: File, maxTotal: Long = 1024L * 1024 * 1024, cancelled: () -> Boolean): List<String> {
        require(kind in listOf("mp3", "playlist", "csv", "cover"))
        require(uris.isNotEmpty() && uris.size <= if (kind == "mp3") 100 else 1)
        check(directory.mkdirs())
        var total = 0L
        return uris.mapIndexed { index, uri ->
            require(uri.scheme == "content" && uri.authority != "${context.packageName}.files")
            val original = context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                .use { cursor -> if (cursor != null && cursor.moveToFirst()) cursor.getString(0) ?: "" else "" }
                .replace(Regex("[^\\p{L}\\p{N} ._()\\-]"), "_").take(180)
            val extension = original.substringAfterLast('.', "").lowercase()
            require(when (kind) { "mp3" -> extension == "mp3"; "csv" -> extension == "csv"; "playlist" -> extension in listOf("csv", "json"); else -> extension in listOf("png", "jpg", "jpeg", "webp") })
            val folder = File(directory, index.toString()).apply { check(mkdirs()) }
            val destination = File(folder, original)
            val limit = when (kind) { "mp3" -> 200L * 1024 * 1024; "playlist", "csv" -> 5L * 1024 * 1024; else -> 10L * 1024 * 1024 }
            total += copyTo(uri, destination, minOf(limit, maxTotal - total), cancelled)
            destination.path
        }
    }

    internal fun copyTo(uri: Uri, destination: File, maxBytes: Long, cancelled: () -> Boolean): Long {
        require(uri.scheme == "content" && uri.authority != "${context.packageName}.files")
        var size = 0L
        context.contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input)
            destination.outputStream().use { output ->
                val buffer = ByteArray(65536)
                while (true) {
                    check(!cancelled())
                    val read = input.read(buffer)
                    if (read == -1) break
                    size += read
                    check(size <= maxBytes) { "O limite de tamanho da importação foi ultrapassado." }
                    output.write(buffer, 0, read)
                }
                output.fd.sync()
            }
        }
        check(size > 0 && !cancelled())
        return size
    }
}
