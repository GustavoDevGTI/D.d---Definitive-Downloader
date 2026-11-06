package br.com.definitivedownloader.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Context

class MainActivity : FlutterActivity() {
    private lateinit var files: AndroidFilesChannel
    override fun provideFlutterEngine(context: Context): FlutterEngine = (application as DdApplication).runtime.engine
    override fun shouldDestroyEngineWithHost() = false
    override fun onResume() {
        super.onResume()
        (application as DdApplication).runtime.background.activity = this
    }
    override fun onPause() {
        (application as DdApplication).runtime.background.activity = null
        super.onPause()
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        files = AndroidFilesChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        (application as DdApplication).runtime.start(dartEntrypointArgs)
    }

    override fun onDestroy() {
        if (::files.isInitialized) files.dispose()
        super.onDestroy()
    }

    @Deprecated("Android activity result bridge required by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        if (!files.onActivityResult(requestCode, resultCode, data)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
}
