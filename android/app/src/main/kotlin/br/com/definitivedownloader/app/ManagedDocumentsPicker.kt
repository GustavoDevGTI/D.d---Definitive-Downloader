package br.com.definitivedownloader.app

import android.app.Activity
import android.content.Intent
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodChannel

class ManagedDocumentsPicker(private val activity: Activity, private val documents: ManagedDocumentsChannel) {
    private var pending: MethodChannel.Result? = null
    fun choose(result: MethodChannel.Result) {
        if (pending != null) { result.error("busy", "Aguarde o seletor aberto.", null); return }
        pending = result
        try {
            activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                .putExtra(DocumentsContract.EXTRA_INITIAL_URI, DocumentsContract.buildDocumentUri("com.android.externalstorage.documents", "primary:Documents")), REQUEST)
        } catch (_: Exception) { pending = null; result.error("destination", "Seletor de pastas indisponível.", null) }
    }
    fun onResult(request: Int, code: Int, intent: Intent?): Boolean {
        if (request != REQUEST) return false
        val result = pending.also { pending = null } ?: return true
        val uri = intent?.data
        if (code != Activity.RESULT_OK || uri == null) { result.success(null); return true }
        try {
            val required = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            require(intent.flags and required == required)
            activity.contentResolver.takePersistableUriPermission(uri, required)
            documents.addDestination(uri, result)
        } catch (_: Exception) { result.error("permission", "O destino não concedeu acesso persistente de leitura e escrita.", null) }
        return true
    }
    fun dispose() { pending?.error("cancelled", "Seleção interrompida.", null); pending = null }
    companion object { const val REQUEST = 4912 }
}
