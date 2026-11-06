package br.com.definitivedownloader.app

import android.content.Context
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import java.io.File
import java.security.MessageDigest
import java.util.UUID
import java.util.zip.ZipInputStream

data class AndroidMusicInstallation(val bundle: File, val python: File,
    val ffmpeg: File, val quickJs: File, val environment: Map<String, String>)

/** Installs only signed APK data, outside user media and account storage. */
object AndroidMusicAssets {
    @Synchronized
    fun prepare(context: Context): AndroidMusicInstallation {
        val app = context.applicationContext
        YoutubeDL.init(app)
        FFmpeg.init(app)
        val hash = app.assets.open("dd_music_bundle.sha256").bufferedReader().use { it.readText().trim() }
        require(hash.matches(Regex("[a-f0-9]{64}")))
        val base = File(app.noBackupFilesDir, "dd-music").apply { check(isDirectory || mkdirs()) }
        val bundle = File(base, hash)
        if (!File(bundle, ".ready").isFile) install(app, base, bundle, hash)
        val bin = File(app.applicationInfo.nativeLibraryDir)
        val python = File(bin, "libpython.so")
        val ffmpeg = File(bin, "libffmpeg.so")
        val quickJs = File(bin, "libqjs.so")
        require(listOf(python, ffmpeg, quickJs).all { it.isFile && it.canExecute() })
        val packages = File(app.noBackupFilesDir, "youtubedl-android/packages")
        val pythonHome = File(packages, "python/usr")
        val environment = mapOf(
            "PYTHONHOME" to pythonHome.path,
            "PYTHONPATH" to File(bundle, "deps").path,
            "LD_LIBRARY_PATH" to listOf(File(pythonHome, "lib"), File(packages, "ffmpeg/usr/lib")).joinToString(":") { it.path },
            "SSL_CERT_FILE" to File(pythonHome, "etc/tls/cert.pem").path,
            "DD_ANDROID_FFMPEG" to ffmpeg.path,
            "DD_ANDROID_QJS" to quickJs.path,
            "DD_ANDROID_RUNTIME" to "1",
            "PYTHONUNBUFFERED" to "1")
        return AndroidMusicInstallation(bundle, python, ffmpeg, quickJs, environment)
    }

    private fun install(context: Context, base: File, destination: File, expected: String) {
        val digest = MessageDigest.getInstance("SHA-256")
        context.assets.open("dd_music_bundle.zip").use { input ->
            val buffer = ByteArray(32768)
            while (true) { val read = input.read(buffer); if (read < 0) break; digest.update(buffer, 0, read) }
        }
        require(digest.digest().joinToString("") { "%02x".format(it.toInt() and 255) } == expected)
        val work = File(base, ".install-${UUID.randomUUID()}").apply { check(mkdir()) }
        try {
            val prefix = work.canonicalPath + File.separator
            var total = 0L
            var entries = 0
            ZipInputStream(context.assets.open("dd_music_bundle.zip")).use { zip ->
                while (true) {
                    val entry = zip.nextEntry ?: break
                    check(++entries <= 10000)
                    require(!entry.name.contains('\\'))
                    val target = File(work, entry.name)
                    require(target.canonicalPath.startsWith(prefix))
                    if (entry.isDirectory) { check(target.isDirectory || target.mkdirs()); continue }
                    check(target.parentFile!!.isDirectory || target.parentFile!!.mkdirs())
                    var length = 0L
                    target.outputStream().use { output ->
                        val buffer = ByteArray(32768)
                        while (true) {
                            val read = zip.read(buffer)
                            if (read < 0) break
                            length += read; total += read
                            require(length <= 20000000 && total <= 80000000)
                            output.write(buffer, 0, read)
                        }
                    }
                }
            }
            require(File(work, "entry.py").isFile && File(work, "core/main.py").isFile)
            File(work, ".ready").writeText(expected)
            // Destination is a hash-named code cache owned solely by this module.
            if (destination.exists()) check(destination.deleteRecursively())
            check(work.renameTo(destination))
        } finally { if (work.exists()) work.deleteRecursively() }
    }
}
