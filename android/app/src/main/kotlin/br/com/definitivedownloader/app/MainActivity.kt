package br.com.definitivedownloader.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private lateinit var files: AndroidFilesChannel
    private lateinit var audio: AndroidAudioChannel
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        files = AndroidFilesChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        audio = AndroidAudioChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onPause() {
        if (::audio.isInitialized) audio.setForeground(false)
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        if (::audio.isInitialized) audio.setForeground(true)
    }

    override fun onDestroy() {
        if (::files.isInitialized) files.dispose()
        if (::audio.isInitialized) audio.dispose()
        super.onDestroy()
    }

    @Deprecated("Android activity result bridge required by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        if (!files.onActivityResult(requestCode, resultCode, data)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
}
