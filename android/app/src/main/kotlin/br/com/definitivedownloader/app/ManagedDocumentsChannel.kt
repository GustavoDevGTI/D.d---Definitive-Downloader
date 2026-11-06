package br.com.definitivedownloader.app

import android.content.Context
import android.app.Activity
import android.content.Intent
import androidx.core.content.FileProvider
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import android.media.MediaMetadataRetriever

class ManagedDocumentsChannel(context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "br.com.definitivedownloader/documents")
    private val executor = Executors.newSingleThreadExecutor()
    private val handler = Handler(Looper.getMainLooper())
    private val db = ManagedDocumentsDb(context)
    private val io = ManagedDocumentIo(context)
    private val targets = ManagedDocumentTargets(context, db, io)
    private val jobs = ManagedDocumentJobs(db, targets, io)
    private val removals = ManagedDocumentRemovals(db, jobs, targets, io)
    private val manifests = ManagedDocumentManifest(db, targets, jobs, io)
    private val cancelled = ConcurrentHashMap<Long, AtomicBoolean>()
    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "cancel") {
                call.argument<Number>("trackId")?.toLong()?.let { cancelled[it]?.set(true) }
                result.success(null)
                return@setMethodCallHandler
            }
            executor.execute {
            try {
                fun string(name: String) = requireNotNull(call.argument<String>(name))
                fun number(name: String) = requireNotNull(call.argument<Number>(name)).toLong()
                val value: Any? = when (call.method) {
                    "destinations" -> targets.destinations()
                    "revoke" -> {
                        val tree = targets.revoke(string("path"))
                        try {
                            context.contentResolver.releasePersistableUriPermission(tree,
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                        } catch (_: SecurityException) { /* Already revoked by Android. Keep the app-side denial. */ }
                        null
                    }
                    "prepare" -> jobs.prepare(string("directory"), number("trackId"), number("collectionId"), string("key"))
                    "reusable" -> jobs.reusable(string("directory"), number("trackId"), string("key"))
                    "publish" -> {
                        val track = number("trackId"); val flag = AtomicBoolean(false); cancelled[track] = flag
                        try { jobs.publish(string("path"), string("directory"), track, number("collectionId"), string("key"), call.argument<String>("fileName")) { flag.get() } }
                        finally { cancelled.remove(track) }
                    }
                    "acknowledge" -> { jobs.acknowledge(string("path")); null }
                    "import" -> jobs.publish(string("path"), string("directory"), -1, number("collectionId"), io.fileHash(File(string("path")))) { false }
                    "bindImport" -> { jobs.bindImport(string("path"), number("trackId"), number("collectionId"), string("key")); null }
                    "rollbackImport" -> { jobs.rollbackImport(string("path")); null }
                    "available" -> jobs.available(string("path"))
                    "owned" -> (jobs.media(string("path")) != null)
                    "tags" -> {
                        val uri = jobs.uri(string("path"))
                        if (uri == null) null else {
                            val retriever = MediaMetadataRetriever()
                            try {
                                retriever.setDataSource(context, Uri.parse(uri))
                                mapOf("title" to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE) ?: ""),
                                    "artist" to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST) ?: ""),
                                    "album" to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM) ?: ""),
                                    "cover" to retriever.embeddedPicture?.takeIf { it.size <= 5 * 1024 * 1024 })
                            } finally { retriever.release() }
                        }
                    }
                    "size" -> jobs.size(string("path"))
                    "pending" -> jobs.pending()
                    "pendingRemovals" -> db.rows("SELECT operation,track_id,path FROM removals ORDER BY rowid LIMIT 1000").map {
                        mapOf("operation" to it.getValue("operation"), "trackId" to it.getValue("track_id").toLong(), "path" to it.getValue("path"))
                    }
                    "playback" -> {
                        val uri = Uri.parse(string("uri"))
                        if (uri.scheme == "file") jobs.uri(requireNotNull(uri.path)) ?: uri.toString() else uri.toString()
                    }
                    "stageRemoval" -> { removals.stage(string("operation"), number("trackId"), string("path")); null }
                    "finishRemoval" -> { removals.finish(string("operation"), string("path"), call.argument<Boolean>("retained") == true); null }
                    "cancelRemovals" -> { removals.cancel(string("operation")); null }
                    "playlist" -> { manifests.publish(string("path")); null }
                    else -> throw IllegalArgumentException()
                }
                handler.post { result.success(value) }
            } catch (_: SecurityException) {
                handler.post { result.error("permission", "Acesso à pasta pública indisponível. Selecione novamente a pasta nas configurações; nenhum download será repetido automaticamente.", null) }
            } catch (error: Exception) {
                val location = error.stackTrace.firstOrNull { it.className.startsWith("br.com.definitivedownloader.app.Managed") }
                android.util.Log.w("DdDocuments", "${call.method}: ${error.javaClass.simpleName} at ${location?.fileName}:${location?.lineNumber}")
                handler.post { result.error("documents", "Não foi possível publicar ou acessar a mídia na pasta pública. Confira permissão, espaço e disponibilidade do destino.", null) }
            }
        } }
    }
    fun addDestination(tree: Uri, result: MethodChannel.Result) {
        executor.execute {
            try { val root = targets.add(tree); handler.post { result.success(root) } }
            catch (_: Exception) { handler.post { result.error("destination", "Não foi possível usar esta pasta pública.", null) } }
        }
    }
    fun openFile(activity: Activity, path: String, result: MethodChannel.Result) {
        executor.execute {
            try {
                val uri = jobs.uri(path)?.let(Uri::parse) ?: FileProvider.getUriForFile(activity, "${activity.packageName}.files", File(path).also { require(it.isFile) })
                handler.post {
                    try { activity.startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, "audio/mpeg").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)); result.success(null) }
                    catch (_: Exception) { result.error("open", "Nenhum aplicativo disponível para este arquivo.", null) }
                }
            } catch (_: Exception) { handler.post { result.error("open", "Arquivo público indisponível. Confira acesso e destino.", null) } }
        }
    }
    fun openFolder(activity: Activity, path: String, result: MethodChannel.Result, fallback: (String) -> Unit) {
        executor.execute {
            try {
                val target = targets.target(path)
                if (target == null) { handler.post { fallback(path) }; return@execute }
                val uri = if (path == target.getValue("root")) Uri.parse(target.getValue("tree")).let {
                    android.provider.DocumentsContract.buildDocumentUriUsingTree(it, android.provider.DocumentsContract.getTreeDocumentId(it))
                } else requireNotNull(targets.knownFolder(path))
                handler.post {
                    try { activity.startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, android.provider.DocumentsContract.Document.MIME_TYPE_DIR).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)); result.success(null) }
                    catch (_: Exception) { result.error("folder", "Abra a pasta selecionada no gerenciador de arquivos do Android.", null) }
                }
            } catch (_: Exception) { handler.post { result.error("folder", "Pasta pública indisponível. Confira a permissão e o volume.", null) } }
        }
    }
}
