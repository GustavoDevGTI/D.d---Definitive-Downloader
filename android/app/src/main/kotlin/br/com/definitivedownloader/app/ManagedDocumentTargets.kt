package br.com.definitivedownloader.app

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract as Docs
import java.io.File
import java.util.UUID

internal class ManagedDocumentTargets(private val context: Context, private val db: ManagedDocumentsDb, private val io: ManagedDocumentIo) {
    fun add(tree: Uri): String {
        require(tree.scheme == "content" && Docs.isTreeUri(tree))
        val existing = db.rows("SELECT root FROM targets WHERE tree=?", tree).firstOrNull()
        if (existing != null) {
            db.writableDatabase.execSQL("UPDATE targets SET enabled=1 WHERE root=?", arrayOf(existing.getValue("root")))
            return existing.getValue("root")
        }
        check(db.rows("SELECT root FROM targets LIMIT 128").size < 128)
        val parent = Docs.buildDocumentUriUsingTree(tree, Docs.getTreeDocumentId(tree))
        io.children(parent) // Verify the grant/provider now, not at first transfer.
        val root = File(context.filesDir, "Definitive Downloader/Documentos/${UUID.randomUUID()}").apply { check(mkdirs()) }.canonicalFile
        db.insert("targets", mapOf("root" to root.path, "tree" to tree.toString(), "label" to "Pasta pública / ${Docs.getTreeDocumentId(tree).substringAfter(':')}"))
        return root.path
    }
    fun target(directory: String): Map<String, String>? {
        val file = File(directory).absoluteFile
        val target = db.rows("SELECT * FROM targets LIMIT 129").firstOrNull { row ->
            file.path == row.getValue("root") || file.path.startsWith(row.getValue("root") + File.separator)
        }
        if (target != null) {
            if (target.getValue("enabled") != "1") throw SecurityException("Destino revogado.")
            val root = File(target.getValue("root"))
            val relative = file.relativeTo(root).path
            require(relative.split(File.separatorChar).none { it == ".." || it == "." })
            require(file.canonicalFile == File(root.canonicalFile, relative))
        }
        return target
    }
    fun folder(directory: String): Uri {
        val target = requireNotNull(target(directory))
        require(File(directory).parent == target.getValue("root"))
        val parent = Uri.parse(target.getValue("tree")).let { Docs.buildDocumentUriUsingTree(it, Docs.getTreeDocumentId(it)) }
        val existing = db.rows("SELECT uri FROM folders WHERE path=?", directory).firstOrNull()
        if (existing != null) {
            val uri = Uri.parse(existing.getValue("uri"))
            if (io.present(uri, parent)) return uri
            // Called only for an explicit publication; availability checks use
            // knownFolder and never recreate a removed playlist by themselves.
            val recreated = io.create(parent, Docs.Document.MIME_TYPE_DIR, File(directory).name)
            check(io.name(recreated) == File(directory).name)
            db.writableDatabase.execSQL("UPDATE folders SET uri=? WHERE path=?", arrayOf(recreated.toString(), directory))
            return recreated
        }
        val uri = io.create(parent, Docs.Document.MIME_TYPE_DIR, File(directory).name)
        // A conflicting folder belongs to somebody else; don't silently merge.
        check(io.name(uri) == File(directory).name) { "Já existe uma pasta com esse nome no destino." }
        db.insert("folders", mapOf("path" to directory, "uri" to uri.toString(), "root" to target.getValue("root")))
        return uri
    }
    fun knownFolder(directory: String): Uri? = db.rows("SELECT uri FROM folders WHERE path=?", directory).firstOrNull()?.getValue("uri")?.let(Uri::parse)
    fun destinations(): List<Map<String, String>> = db.rows("SELECT root,label FROM targets LIMIT 129")
    fun revoke(path: String): Uri {
        val target = db.rows("SELECT * FROM targets WHERE root=?", path).single()
        db.writableDatabase.execSQL("UPDATE targets SET enabled=0 WHERE root=?", arrayOf(target.getValue("root")))
        return Uri.parse(target.getValue("tree"))
    }
}
