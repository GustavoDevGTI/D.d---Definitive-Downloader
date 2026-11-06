package br.com.definitivedownloader.app

import android.net.Uri
import java.io.File
import java.util.UUID

internal class ManagedDocumentJobs(private val db: ManagedDocumentsDb, private val targets: ManagedDocumentTargets, private val io: ManagedDocumentIo) {
    fun reusable(directory: String, track: Long, key: String): String? {
        if (targets.target(directory) == null) return null
        val jobs = db.rows("SELECT * FROM jobs WHERE track_id=? AND directory=? AND source_key=? AND state!='removed' ORDER BY rowid DESC LIMIT 20", track, directory, key)
        for (job in jobs) {
            val path = job.getValue("path")
            if (path.isNotEmpty() && File(path).isFile) return path
            if (job.getValue("alias").isNotEmpty() && File(job.getValue("alias")).isFile) return job.getValue("alias")
            val folder = File(job.getValue("stage"))
            if (!folder.exists()) continue
            require(folder.canonicalFile == folder.absoluteFile && folder.parent == directory && folder.name == ".dd-transfer-${job.getValue("id")}")
            val finals = folder.listFiles()?.filter { it.isFile && it.extension == "mp3" && it.canonicalFile == it.absoluteFile } ?: emptyList()
            require(finals.size <= 1)
            if (finals.size == 1) return finals.single().path
        }
        return null
    }
    fun prepare(directory: String, track: Long, collection: Long, key: String): String {
        if (targets.target(directory) == null) return directory
        require(Regex("[a-f0-9]{64}").matches(key) && track > 0 && collection > 0)
        File(directory).apply { check(isDirectory || mkdirs()) }
        val id = UUID.randomUUID().toString()
        val stage = File(directory, ".dd-transfer-$id")
        db.insert("jobs", mapOf("id" to id, "track_id" to track, "collection_id" to collection,
            "directory" to directory, "source_key" to key, "stage" to stage.path))
        check(stage.mkdir())
        return stage.path
    }
    fun publish(path: String, directory: String, track: Long, collection: Long, key: String, fileName: String? = null, cancelled: () -> Boolean): String {
        if (targets.target(directory) == null) return path
        val source = File(path).absoluteFile
        val desiredName = fileName ?: source.name
        require(File(desiredName).name == desiredName && desiredName.endsWith(".mp3") && !desiredName.contains('/'))
        require(source.canonicalFile == source && source.isFile)
        var job = db.rows("SELECT * FROM jobs WHERE track_id=? AND collection_id=? AND directory=? AND source_key=? AND (stage=? OR path=? OR alias=?) ORDER BY rowid DESC LIMIT 1",
            track, collection, directory, key, source.parent, path, path).firstOrNull()
        // Local-file import also uses this publisher, after its own validation.
        if (job == null) {
            require(source.parent == directory && source.extension == "mp3")
            val id = UUID.randomUUID().toString()
            db.insert("jobs", mapOf("id" to id, "track_id" to track, "collection_id" to collection,
                "directory" to directory, "source_key" to key, "stage" to "", "path" to path))
            job = db.rows("SELECT * FROM jobs WHERE id=?", id).single()
        }
        val id = job.getValue("id")
        val parent = targets.folder(directory)
        if (job.getValue("state") == "renaming") {
            val found = io.find(parent, File(job.getValue("alias")).name)
            if (found != null && io.documentHash(found, job.getValue("size").toLong()) == job.getValue("hash")) {
                db.updateJob(id, mapOf("uri" to found.toString(), "state" to "published"))
                job = db.rows("SELECT * FROM jobs WHERE id=?", id).single()
            }
        }
        if (job.getValue("state") in listOf("published", "committed")) {
            check(File(job.getValue("alias")).name == desiredName) {
                "A mídia já publicada conserva sua numeração até reconciliar a conclusão."
            }
            val uri = Uri.parse(job.getValue("uri"))
            check(io.present(uri, parent))
            check(io.documentHash(uri, job.getValue("size").toLong()) == job.getValue("hash"))
            val alias = File(job.getValue("alias"))
            if (!alias.exists() && source.path != alias.path) check(source.renameTo(alias))
            db.updateJob(id, mapOf("path" to alias.path))
            db.bindMedia(alias.path, id)
            return job.getValue("alias")
        }
        val size = source.length()
        val hash = io.fileHash(source)
        db.updateJob(id, mapOf("path" to path, "size" to size, "hash" to hash, "name" to source.name, "state" to "validated"))
        var uri = job.getValue("uri").takeIf { it.isNotEmpty() }?.let(Uri::parse)
        val temporaryName = ".dd-$id.mp3"
        if (uri == null || !io.present(uri, parent)) {
            uri = io.create(parent, "audio/mpeg", temporaryName)
            db.updateJob(id, mapOf("uri" to uri.toString(), "state" to "copying"))
        } else {
            check(io.name(uri) == temporaryName) { "O documento temporário foi alterado fora do app." }
        }
        io.copy(source, uri, cancelled)
        check(io.documentHash(uri, size) == hash && !cancelled())
        var alias = File(directory, desiredName)
        if (alias.exists() && alias.path != source.path) alias = File(directory, "${desiredName.removeSuffix(".mp3")} [$id].mp3")
        if (io.find(parent, alias.name) != null) alias = File(directory, "${desiredName.removeSuffix(".mp3")} [$id].mp3")
        check(io.find(parent, alias.name) == null) { "O destino já contém esse nome. Nada foi substituído." }
        // Persist the exact temporary URI and final names before remote rename.
        db.updateJob(id, mapOf("alias" to alias.path, "name" to alias.name, "state" to "renaming"))
        uri = io.rename(uri, alias.name)
        db.updateJob(id, mapOf("uri" to uri.toString()))
        check(io.name(uri) == alias.name)
        db.updateJob(id, mapOf("state" to "published"))
        if (source.path != alias.path) check(source.renameTo(alias))
        db.updateJob(id, mapOf("path" to alias.path))
        db.bindMedia(alias.path, id)
        return alias.path
    }
    fun media(path: String): Map<String, String>? = db.rows("SELECT j.* FROM media m JOIN jobs j ON j.id=m.job WHERE m.path=?", path).firstOrNull()
    fun acknowledge(path: String) { media(path)?.let {
        val cache = File(path)
        require(cache.parent == it.getValue("directory") && cache.canonicalFile == cache.absoluteFile)
        if (cache.isFile) check(cache.delete()) // Public bytes remain authoritative.
        val stage = File(it.getValue("stage"))
        if (stage.parent == it.getValue("directory") && stage.name == ".dd-transfer-${it.getValue("id")}" && stage.isDirectory && stage.listFiles()?.isEmpty() == true) check(stage.delete())
        db.updateJob(it.getValue("id"), mapOf("state" to "committed"))
    } }
    fun bindImport(path: String, track: Long, collection: Long, key: String) {
        val job = media(path) ?: return
        require(job.getValue("collection_id").toLong() == collection)
        require(job.getValue("track_id").toLong() == -1L || job.getValue("track_id").toLong() == track)
        db.updateJob(job.getValue("id"), mapOf("track_id" to track, "source_key" to key))
        acknowledge(path)
    }
    fun rollbackImport(path: String) {
        val job = media(path) ?: db.rows("SELECT * FROM jobs WHERE path=? AND track_id=-1 ORDER BY rowid DESC LIMIT 1", path).firstOrNull() ?: return
        require(job.getValue("track_id").toLong() == -1L)
        val parent = requireNotNull(targets.knownFolder(job.getValue("directory")))
        var uri = job.getValue("uri").takeIf { it.isNotEmpty() }?.let(Uri::parse)
        if (uri != null && !io.present(uri, parent) && job.getValue("state") == "renaming" && job.getValue("alias").isNotEmpty()) {
            uri = io.find(parent, File(job.getValue("alias")).name)
        }
        if (uri != null && io.present(uri, parent)) {
            if (job.getValue("state") in listOf("published", "committed", "renaming")) check(io.documentHash(uri, job.getValue("size").toLong()) == job.getValue("hash"))
            else check(io.name(uri) == ".dd-${job.getValue("id")}.mp3")
            io.delete(uri, parent)
        }
        for (path in listOf(job.getValue("path"), job.getValue("alias")).filter { it.isNotEmpty() }.distinct()) {
            val cache = File(path)
            require(cache.parent == job.getValue("directory") && cache.canonicalFile == cache.absoluteFile)
            if (cache.isFile) check(cache.delete())
        }
        db.updateJob(job.getValue("id"), mapOf("state" to "removed"))
    }
    fun available(path: String): Boolean? {
        val job = media(path) ?: return if (targets.target(File(path).parent ?: "") != null) false else null
        if (job.getValue("state") == "removed") return false
        val parent = targets.knownFolder(job.getValue("directory")) ?: error("Pasta pública indisponível.")
        val target = requireNotNull(targets.target(job.getValue("directory")))
        val tree = Uri.parse(target.getValue("tree")).let { android.provider.DocumentsContract.buildDocumentUriUsingTree(it, android.provider.DocumentsContract.getTreeDocumentId(it)) }
        if (!io.present(parent, tree)) return false
        return io.present(Uri.parse(job.getValue("uri")), parent)
    }
    fun uri(path: String): String? {
        val job = media(path) ?: return null
        check(available(path) == true)
        return job.getValue("uri")
    }
    fun size(path: String): Long? {
        val job = media(path)
        return if (job == null) File(path).takeIf { it.isFile }?.length()
        else if (available(path) == true) io.size(Uri.parse(job.getValue("uri"))) ?: job.getValue("size").toLong() else null
    }
    fun pending(): List<Map<String, Any>> = db.rows("SELECT * FROM jobs WHERE (track_id>0 AND state='published' AND alias!='') OR (track_id=-1 AND state NOT IN ('committed','removed')) ORDER BY rowid LIMIT 1000").map { job ->
        if (job.getValue("state") == "published") {
            val parent = requireNotNull(targets.knownFolder(job.getValue("directory")))
            val uri = Uri.parse(job.getValue("uri"))
            check(io.present(uri, parent) && io.documentHash(uri, job.getValue("size").toLong()) == job.getValue("hash"))
            db.bindMedia(job.getValue("alias"), job.getValue("id"))
        }
        buildMap<String, Any> {
            put("trackId", job.getValue("track_id").toLong())
            put("path", job.getValue("alias").ifEmpty { job.getValue("path") })
            put("key", job.getValue("source_key"))
            Regex("^(\\d+) - ").find(job.getValue("name"))?.groupValues?.get(1)?.toLongOrNull()?.let { put("position", it) }
        }
    }
}
