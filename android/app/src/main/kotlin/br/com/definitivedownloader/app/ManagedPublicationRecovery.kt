package br.com.definitivedownloader.app

import android.net.Uri
import java.io.File

/** Observe a finished remote rename; never publish or approve unfinished work. */
internal class ManagedPublicationRecovery(private val db: ManagedDocumentsDb,
    private val targets: ManagedDocumentTargets, private val io: ManagedDocumentIo) {
    fun pending(): List<Map<String, Any>> {
        val rows = db.rows("SELECT * FROM jobs WHERE (track_id>0 AND state IN ('published','renaming') AND alias!='') OR (track_id=-1 AND state NOT IN ('committed','removed')) ORDER BY rowid LIMIT 1001")
        require(rows.size <= 1000)
        return rows.mapNotNull { original ->
            var job = original
            if (job.getValue("state") == "renaming") {
                targets.target(job.getValue("directory")) // Preserve revocation/volume failures.
                val parent = requireNotNull(targets.knownFolder(job.getValue("directory")))
                val found = io.find(parent, File(job.getValue("alias")).name)
                if (found == null) return@mapNotNull null // Still temporary: wait for an explicit retry.
                check(io.documentHash(found, job.getValue("size").toLong()) == job.getValue("hash"))
                db.updateJob(job.getValue("id"), mapOf("uri" to found.toString(), "state" to "published"))
                job = db.rows("SELECT * FROM jobs WHERE id=?", job.getValue("id")).single()
            }
            if (job.getValue("state") == "published") {
                targets.target(job.getValue("directory"))
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
}
