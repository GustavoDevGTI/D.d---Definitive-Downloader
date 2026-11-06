package br.com.definitivedownloader.app

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

internal class ManagedDocumentsDb(context: Context) : SQLiteOpenHelper(context, "managed-documents.sqlite3", null, 2) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE targets(root TEXT PRIMARY KEY,tree TEXT NOT NULL UNIQUE,label TEXT NOT NULL,enabled INTEGER NOT NULL DEFAULT 1)")
        db.execSQL("CREATE TABLE folders(path TEXT PRIMARY KEY,uri TEXT NOT NULL,root TEXT NOT NULL)")
        db.execSQL("""CREATE TABLE jobs(id TEXT PRIMARY KEY,track_id INTEGER NOT NULL,collection_id INTEGER NOT NULL,
            directory TEXT NOT NULL,source_key TEXT NOT NULL,stage TEXT NOT NULL,path TEXT NOT NULL DEFAULT '',
            uri TEXT NOT NULL DEFAULT '',name TEXT NOT NULL DEFAULT '',size INTEGER NOT NULL DEFAULT 0,
            hash TEXT NOT NULL DEFAULT '',state TEXT NOT NULL DEFAULT 'allocated',alias TEXT NOT NULL DEFAULT '')""")
        db.execSQL("CREATE INDEX jobs_track ON jobs(track_id,directory,source_key)")
        db.execSQL("CREATE TABLE media(path TEXT PRIMARY KEY,job TEXT NOT NULL REFERENCES jobs(id))")
        db.execSQL("CREATE TABLE removals(operation TEXT NOT NULL,path TEXT NOT NULL,track_id INTEGER NOT NULL,job TEXT NOT NULL,PRIMARY KEY(operation,path))")
    }
    override fun onConfigure(db: SQLiteDatabase) { db.setForeignKeyConstraintsEnabled(true) }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) db.execSQL("ALTER TABLE targets ADD COLUMN enabled INTEGER NOT NULL DEFAULT 1")
    }
    fun rows(sql: String, vararg arguments: Any): List<Map<String, String>> = readableDatabase.rawQuery(sql, arguments.map { it.toString() }.toTypedArray()).use { cursor ->
        buildList {
            while (cursor.moveToNext()) {
                check(size < 10000)
                add(cursor.columnNames.associateWith { cursor.getString(cursor.getColumnIndexOrThrow(it)) ?: "" })
            }
        }
    }
    fun insert(table: String, values: Map<String, Any>) {
        writableDatabase.insertOrThrow(table, null, ContentValues().apply { values.forEach { (key, value) -> put(key, value.toString()) } })
    }
    fun updateJob(id: String, values: Map<String, Any>) {
        writableDatabase.update("jobs", ContentValues().apply { values.forEach { (key, value) -> put(key, value.toString()) } }, "id=?", arrayOf(id))
    }
    fun bindMedia(path: String, job: String) = writableDatabase.execSQL(
        "INSERT INTO media(path,job) VALUES(?,?) ON CONFLICT(path) DO UPDATE SET job=excluded.job", arrayOf(path, job))
}
