package br.com.definitivedownloader.app

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

/** The process owns the engine; an Activity only attaches the UI/documents. */
class DdApplication : Application() {
    val runtime by lazy { AndroidRuntime(this) }
}

class AndroidRuntime(app: Application) {
    val engine = FlutterEngine(app)
    val background = AndroidBackgroundChannel(app, engine.dartExecutor.binaryMessenger)
    val audio = AndroidAudioChannel(app, engine.dartExecutor.binaryMessenger, background::audioState)
    val music = AndroidMusicChannel(app, engine.dartExecutor.binaryMessenger)
    val incoming = AndroidShareInbox(app, engine.dartExecutor.binaryMessenger)
    val documents = ManagedDocumentsChannel(app, engine.dartExecutor.binaryMessenger)
    init { background.audio = audio }

    fun start(args: List<String>?) {
        if (!engine.dartExecutor.isExecutingDart) {
            engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault(), args)
        }
    }
}
