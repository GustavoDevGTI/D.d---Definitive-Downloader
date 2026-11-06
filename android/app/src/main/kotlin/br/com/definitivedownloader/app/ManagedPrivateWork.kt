package br.com.definitivedownloader.app

import java.io.File
import java.util.UUID

/** Retires only a relationally recorded, unfinished private transfer attempt. */
internal class ManagedPrivateWork(private val db: ManagedDocumentsDb) {
    fun retire(directory: String, track: Long, key: String) {
        val rows = db.rows("SELECT id,stage FROM jobs WHERE track_id=? AND directory=? AND source_key=? AND state='allocated' AND uri='' AND alias='' AND path='' ORDER BY rowid LIMIT 1001", track, directory, key)
        require(rows.size <= 1000)
        for (row in rows) {
            val id = row.getValue("id")
            require(UUID.fromString(id).toString() == id)
            val folder = File(row.getValue("stage")).absoluteFile
            require(folder.parent == directory && folder.name == ".dd-transfer-$id")
            if (folder.exists()) {
                require(folder.canonicalFile == folder && folder.isDirectory)
                check(folder.listFiles()?.none { it.isFile && it.extension == "mp3" } == true) {
                    "Há áudio recebido aguardando publicação. Nenhuma nova obtenção foi iniciada."
                }
                val entries = mutableListOf<File>()
                fun inspect(file: File, depth: Int) {
                    require(depth <= 8 && entries.size < 2000 && file.canonicalFile == file.absoluteFile)
                    entries.add(file)
                    if (file.isDirectory) {
                        val children = requireNotNull(file.listFiles())
                        require(children.size <= 2000)
                        children.forEach { inspect(it, depth + 1) }
                    } else require(file.isFile)
                }
                inspect(folder, 0)
                // Validate all descendants before deleting anything. Directories
                // are deleted only when empty; no recursive/prefix cleanup.
                entries.asReversed().forEach { file ->
                    require(file.canonicalFile == file.absoluteFile)
                    if (file.isDirectory) check(file.listFiles()?.isEmpty() == true)
                    check(file.delete())
                }
            }
            db.writableDatabase.execSQL("DELETE FROM jobs WHERE id=? AND state='allocated' AND uri='' AND alias='' AND path=''", arrayOf(id))
        }
    }
}
