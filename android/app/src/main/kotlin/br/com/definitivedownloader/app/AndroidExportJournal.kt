package br.com.definitivedownloader.app

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.net.Uri
import android.provider.DocumentsContract

/** Only exact created documents are recoverable; unknown public content blocks deletion. */
class AndroidExportJournal(private val context: Context) {
    private val store = Store(context)
    private val resolver = context.contentResolver
    private data class Entry(val uri: Uri, val parent: String, val directory: Boolean)

    fun begin(id: String, uri: Uri) {
        store.writableDatabase.insertOrThrow("exports", null, ContentValues().apply {
            put("id", id); put("uri", uri.toString())
        })
    }
    fun created(id: String, uri: Uri, parent: Uri, directory: Boolean) {
        store.writableDatabase.insertOrThrow("documents", null, ContentValues().apply {
            put("operation", id); put("uri", uri.toString()); put("parent", parent.toString())
            put("directory", if (directory) 1 else 0)
        })
    }
    fun complete(id: String) {
        val db = store.writableDatabase
        db.beginTransaction()
        try {
            db.delete("documents", "operation=?", arrayOf(id))
            db.delete("exports", "id=?", arrayOf(id))
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }
    fun hasPending() = store.readableDatabase.rawQuery("SELECT 1 FROM exports LIMIT 1", null).use { it.moveToFirst() }
    fun recover(): Boolean {
        val operations = store.readableDatabase.rawQuery("SELECT id,uri FROM exports", null).use { cursor ->
            buildList { while (cursor.moveToNext()) add(cursor.getString(0) to Uri.parse(cursor.getString(1))) }
        }
        return operations.map { (id, root) -> cleanup(id, root) }.all { it }
    }
    fun cleanup(id: String, root: Uri): Boolean = runCatching {
        val entries = store.readableDatabase.rawQuery(
            "SELECT uri,parent,directory FROM documents WHERE operation=? ORDER BY rowid", arrayOf(id)).use { cursor ->
            buildList { while (cursor.moveToNext()) add(Entry(Uri.parse(cursor.getString(0)), cursor.getString(1), cursor.getInt(2) == 1)) }
        }
        val directories = listOf(Entry(root, "", true)) + entries.filter { it.directory }
        val tree = DocumentsContract.buildDocumentUriUsingTree(root, DocumentsContract.getTreeDocumentId(root))
        if (DocumentsContract.getDocumentId(root) !in children(tree)) {
            complete(id)
            return@runCatching true
        }
        val present = mutableSetOf(root.toString())
        directories.drop(1).forEach { directory ->
            if (directory.parent in present && DocumentsContract.getDocumentId(directory.uri) in children(Uri.parse(directory.parent))) {
                present.add(directory.uri.toString())
            }
        }
        // Check every directory before deleting any file. No prefix ownership,
        // recursive delete or assumption that an unavailable SD is an empty tree.
        for (directory in directories.filter { it.uri.toString() in present }) {
            val children = children(directory.uri)
            val expected = entries.filter { it.parent == directory.uri.toString() }
                .map { DocumentsContract.getDocumentId(it.uri) }.toSet()
            check(children.all { it in expected })
        }
        entries.filter { !it.directory }.forEach { entry ->
            if (entry.parent in present && DocumentsContract.getDocumentId(entry.uri) in children(Uri.parse(entry.parent))) {
                check(DocumentsContract.deleteDocument(resolver, entry.uri))
            }
        }
        directories.asReversed().filter { it.uri.toString() in present }.forEach { entry ->
            check(children(entry.uri).isEmpty())
            check(DocumentsContract.deleteDocument(resolver, entry.uri))
        }
        complete(id)
        true
    }.getOrDefault(false)

    private fun children(uri: Uri): Set<String> {
        val listing = DocumentsContract.buildChildDocumentsUriUsingTree(uri, DocumentsContract.getDocumentId(uri))
        return resolver.query(listing, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID), null, null, null).use { cursor ->
            checkNotNull(cursor)
            buildSet {
                while (cursor.moveToNext()) { check(size < 12000); add(cursor.getString(0)) }
            }
        }
    }
    private class Store(context: Context) : SQLiteOpenHelper(context, "public-exports.sqlite3", null, 2) {
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL("CREATE TABLE exports(id TEXT PRIMARY KEY,uri TEXT NOT NULL)")
            createDocuments(db)
        }
        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) { if (oldVersion < 2) createDocuments(db) }
        private fun createDocuments(db: SQLiteDatabase) {
            db.execSQL("CREATE TABLE documents(operation TEXT NOT NULL,uri TEXT PRIMARY KEY,parent TEXT NOT NULL,directory INTEGER NOT NULL)")
            db.execSQL("CREATE INDEX documents_operation ON documents(operation)")
        }
    }
}
