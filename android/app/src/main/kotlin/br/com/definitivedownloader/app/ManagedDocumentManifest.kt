package br.com.definitivedownloader.app

import android.net.Uri
import java.io.File
import java.util.UUID

internal class ManagedDocumentManifest(private val db: ManagedDocumentsDb, private val targets: ManagedDocumentTargets,
    private val jobs: ManagedDocumentJobs, private val io: ManagedDocumentIo) {
    fun publish(path: String) {
        val file = File(path).absoluteFile
        if (targets.target(file.parent!!) == null) return
        require(file.name == "playlist.m3u8" && file.canonicalFile == file && file.length() <= 5L * 1024 * 1024)
        val parent = targets.folder(file.parent!!)
        val hash = io.fileHash(file)
        for (previous in db.rows("SELECT * FROM jobs WHERE track_id=0 AND path=? AND source_key!=? AND state NOT IN ('committed','removed') ORDER BY rowid LIMIT 100", path, hash)) {
            val temporary = Uri.parse(previous.getValue("uri"))
            if (previous.getValue("state") == "copying") {
                if (io.present(temporary, parent)) {
                    check(io.name(temporary) == ".dd-manifest-${previous.getValue("id")}.m3u8")
                    io.delete(temporary, parent)
                }
                db.updateJob(previous.getValue("id"), mapOf("state" to "removed"))
            } else {
                val final = io.find(parent, file.name)
                var restored = final?.takeIf { io.matches(it, previous.getValue("size").toLong(), previous.getValue("hash")) }
                if (restored == null) {
                    check(io.present(temporary, parent) && io.documentHash(temporary, previous.getValue("size").toLong()) == previous.getValue("hash"))
                    val old = jobs.media(path)
                    if (old != null) {
                        val oldUri = Uri.parse(old.getValue("uri"))
                        if (io.present(oldUri, parent)) {
                            check(io.documentHash(oldUri, old.getValue("size").toLong()) == old.getValue("hash"))
                            io.delete(oldUri, parent)
                        }
                    } else check(final == null)
                    restored = io.rename(temporary, file.name)
                    check(io.name(restored) == file.name)
                }
                db.updateJob(previous.getValue("id"), mapOf("uri" to restored.toString(), "state" to "committed"))
                db.bindMedia(path, previous.getValue("id"))
            }
        }
        var job = db.rows("SELECT * FROM jobs WHERE track_id=0 AND path=? AND source_key=? AND state!='committed' ORDER BY rowid DESC LIMIT 1", path, hash).firstOrNull()
        if (job == null) {
            val id = UUID.randomUUID().toString()
            val temporary = io.create(parent, "application/octet-stream", ".dd-manifest-$id.m3u8")
            db.insert("jobs", mapOf("id" to id, "track_id" to 0, "collection_id" to 0,
                "directory" to file.parent!!, "source_key" to hash, "stage" to "", "path" to path,
                "uri" to temporary.toString(), "name" to file.name, "size" to file.length(), "hash" to hash,
                "state" to "copying", "alias" to path))
            job = db.rows("SELECT * FROM jobs WHERE id=?", id).single()
        }
        val id = job.getValue("id")
        var uri = Uri.parse(job.getValue("uri"))
        if (job.getValue("state") == "replacing") {
            val published = io.find(parent, file.name)
            if (published != null && io.matches(published, file.length(), hash)) {
                db.updateJob(id, mapOf("uri" to published.toString(), "state" to "committed")); db.bindMedia(path, id)
                return
            }
        }
        check(io.present(uri, parent))
        io.copy(file, uri) { false }
        check(io.documentHash(uri, file.length()) == hash)
        val previous = jobs.media(path)
        if (previous != null) {
            val old = Uri.parse(previous.getValue("uri"))
            if (io.present(old, parent)) {
                check(io.documentHash(old, previous.getValue("size").toLong()) == previous.getValue("hash")) {
                    "A playlist pública foi alterada fora do app. Nada foi substituído."
                }
            }
            db.updateJob(id, mapOf("state" to "replacing"))
            io.delete(old, parent)
        } else {
            check(io.find(parent, file.name) == null)
            db.updateJob(id, mapOf("state" to "replacing"))
        }
        uri = io.rename(uri, file.name)
        db.updateJob(id, mapOf("uri" to uri.toString()))
        check(io.name(uri) == file.name)
        db.updateJob(id, mapOf("state" to "committed")); db.bindMedia(path, id)
    }
}
