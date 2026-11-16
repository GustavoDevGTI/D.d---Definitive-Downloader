package br.com.definitivedownloader.app

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/** Durable small inbox, separate from the library. Nothing is imported on receipt. */
class AndroidShareInbox(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "br.com.definitivedownloader/incoming")
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val store = Store(context)
    private val flags = context.getSharedPreferences("incoming-flags", Context.MODE_PRIVATE)
    private val root = File(context.filesDir, "share-inbox").apply { mkdirs() }

    init {
        channel.setMethodCallHandler { call, result ->
            executor.execute {
                try {
                    val value: Any? = when (call.method) {
                        "peek" -> peek()
                        "finish" -> { finish(requireNotNull(call.argument<String>("id"))); null }
                        else -> throw IllegalArgumentException()
                    }
                    main.post { result.success(value) }
                } catch (_: Exception) {
                    main.post { result.error("incoming", "Não foi possível acessar o compartilhamento recebido.", null) }
                }
            }
        }
        executor.execute {
            // A process death while copying never turns a partial file into an import.
            store.writableDatabase.execSQL("UPDATE batches SET ready=1,error=? WHERE ready=0",
                arrayOf("O recebimento foi interrompido. Compartilhe novamente."))
        }
    }

    @Suppress("DEPRECATION")
    fun receive(intent: Intent?) {
        val csv = intent?.type in setOf("text/csv", "application/csv", "application/vnd.ms-excel")
        val action = intent?.action
        if (action !in listOf(Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE) &&
            !(action == Intent.ACTION_VIEW && csv)) return
        val text = intent?.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString() ?: ""
        val streams = when (action) {
            Intent.ACTION_VIEW -> listOfNotNull(intent?.data)
            Intent.ACTION_SEND_MULTIPLE ->
                intent?.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.toList() ?: emptyList()
            else -> listOfNotNull(intent?.getParcelableExtra<Uri>(Intent.EXTRA_STREAM) ?: intent?.clipData?.takeIf { it.itemCount == 1 }?.getItemAt(0)?.uri)
        }
        executor.execute {
            val db = store.writableDatabase
            val count = db.rawQuery("SELECT COUNT(*) FROM batches", null).use { it.moveToFirst(); it.getInt(0) }
            if (count >= 8) {
                flags.edit().putBoolean("overflow", true).commit()
                main.post { channel.invokeMethod("changed", null) }
                return@execute
            }
            val id = UUID.randomUUID().toString()
            db.insertOrThrow("batches", null, ContentValues().apply {
                put("id", id); put("text", ""); put("error", ""); put("ready", 0)
            })
            val directory = File(root, id)
            try {
                val paths = if (streams.isNotEmpty()) {
                    val bytes = db.rawQuery("SELECT COALESCE(SUM(size),0) FROM files", null).use { it.moveToFirst(); it.getLong(0) }
                    require(bytes < 1024L * 1024 * 1024)
                    AndroidDocumentCopies(context).copy(streams, if (csv) "csv" else "mp3", directory, 1024L * 1024 * 1024 - bytes) { false }.also { copies ->
                        require(bytes + copies.sumOf { File(it).length() } <= 1024L * 1024 * 1024)
                    }
                } else {
                    require(!csv && text.isNotBlank() && text.length <= 32768)
                    emptyList()
                }
                db.beginTransaction()
                try {
                    paths.forEach { path -> db.insertOrThrow("files", null, ContentValues().apply {
                        put("batch", id); put("path", path); put("size", File(path).length())
                    }) }
                    db.execSQL("UPDATE batches SET text=?,ready=1 WHERE id=?", arrayOf(if (paths.isEmpty()) text else "", id))
                    db.setTransactionSuccessful()
                } finally { db.endTransaction() }
            } catch (_: Exception) {
                directory.deleteRecursively() // UUID directory created only by this receipt.
                db.execSQL("UPDATE batches SET ready=1,error=? WHERE id=?",
                    arrayOf(if (csv) "CSV indisponível, inválido ou maior que 5 MB." else
                        "Link vazio, arquivo indisponível ou limite excedido (100 MP3, 200 MB por arquivo e 1 GB na caixa de entrada).", id))
            }
            main.post { channel.invokeMethod("changed", null) }
        }
    }

    private fun peek(): Map<String, Any>? {
        if (flags.getBoolean("overflow", false)) return mapOf("id" to "overflow", "text" to "", "files" to emptyList<String>(),
            "error" to "A caixa de entrada já tem oito compartilhamentos. Revise-os antes de compartilhar novamente.")
        return store.readableDatabase.rawQuery(
        "SELECT id,text,error FROM batches WHERE ready=1 ORDER BY rowid LIMIT 1", null).use { cursor ->
        if (!cursor.moveToFirst()) null else {
            val id = cursor.getString(0)
            val paths = store.readableDatabase.rawQuery("SELECT path FROM files WHERE batch=? ORDER BY rowid", arrayOf(id)).use { files ->
                buildList { while (files.moveToNext()) add(files.getString(0)) }
            }
            mapOf("id" to id, "text" to cursor.getString(1), "error" to cursor.getString(2), "files" to paths)
        }
        }
    }

    private fun finish(id: String) {
        if (id == "overflow") { flags.edit().putBoolean("overflow", false).commit(); return }
        require(UUID.fromString(id).toString() == id)
        val db = store.writableDatabase
        val exists = db.rawQuery("SELECT id FROM batches WHERE id=?", arrayOf(id)).use { it.moveToFirst() }
        if (!exists) return
        check(File(root, id).let { !it.exists() || it.deleteRecursively() })
        db.beginTransaction()
        try {
            db.delete("files", "batch=?", arrayOf(id))
            db.delete("batches", "id=?", arrayOf(id))
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }

    private class Store(context: Context) : SQLiteOpenHelper(context, "incoming.sqlite3", null, 1) {
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL("CREATE TABLE batches(id TEXT PRIMARY KEY,text TEXT NOT NULL,error TEXT NOT NULL,ready INTEGER NOT NULL)")
            db.execSQL("CREATE TABLE files(batch TEXT NOT NULL,path TEXT NOT NULL,size INTEGER NOT NULL)")
            db.execSQL("CREATE INDEX files_batch ON files(batch)")
        }
        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit
    }
}
