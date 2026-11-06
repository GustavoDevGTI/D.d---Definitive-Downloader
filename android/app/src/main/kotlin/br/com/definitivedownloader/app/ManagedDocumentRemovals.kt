package br.com.definitivedownloader.app

import android.net.Uri

internal class ManagedDocumentRemovals(private val db: ManagedDocumentsDb, private val jobs: ManagedDocumentJobs,
    private val targets: ManagedDocumentTargets, private val io: ManagedDocumentIo) {
    fun stage(operation: String, track: Long, path: String) {
        val job = jobs.media(path) ?: return
        targets.target(job.getValue("directory"))
        require(job.getValue("track_id").toLong() == track || job.getValue("track_id").toLong() == -1L)
        val parent = requireNotNull(targets.knownFolder(job.getValue("directory")))
        val uri = Uri.parse(job.getValue("uri"))
        if (io.present(uri, parent)) check(io.documentHash(uri, job.getValue("size").toLong()) == job.getValue("hash")) {
            "O arquivo público foi alterado fora do app. Nada foi excluído."
        }
        db.writableDatabase.execSQL("INSERT OR IGNORE INTO removals VALUES(?,?,?,?)", arrayOf<Any>(operation, path, track, job.getValue("id")))
    }
    fun finish(operation: String, path: String, retained: Boolean) {
        val row = db.rows("SELECT j.* FROM removals r JOIN jobs j ON j.id=r.job WHERE r.operation=? AND r.path=?", operation, path).firstOrNull() ?: return
        if (!retained) {
            targets.target(row.getValue("directory"))
            val current = jobs.media(path)
            if (current != null && current.getValue("id") != row.getValue("id") && current.getValue("uri") == row.getValue("uri")) {
                // Path-based document IDs may be reused after a redownload.
                // Never let an old journal remove the new bound publication.
                db.updateJob(row.getValue("id"), mapOf("state" to "removed"))
                db.writableDatabase.execSQL("DELETE FROM removals WHERE operation=? AND path=?", arrayOf(operation, path))
                return
            }
            val parent = requireNotNull(targets.knownFolder(row.getValue("directory")))
            val uri = Uri.parse(row.getValue("uri"))
            if (io.present(uri, parent)) {
                check(io.documentHash(uri, row.getValue("size").toLong()) == row.getValue("hash"))
                io.delete(uri, parent)
            }
            db.updateJob(row.getValue("id"), mapOf("state" to "removed"))
        }
        db.writableDatabase.execSQL("DELETE FROM removals WHERE operation=? AND path=?", arrayOf(operation, path))
    }
    fun cancel(operation: String) { db.writableDatabase.execSQL("DELETE FROM removals WHERE operation=?", arrayOf(operation)) }
}
