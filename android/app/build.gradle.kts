import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "br.com.definitivedownloader.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "br.com.definitivedownloader.app"
        ndk {
            abiFilters.clear()
            abiFilters.addAll(listOf("arm64-v8a", "x86_64"))
        }
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // The pilot is built in debug mode. Production signing is intentionally
    // unconfigured: a GitHub/Play release must never silently use a debug key.
    buildTypes {
        debug {
            val entry = project.findProperty("target")?.toString()?.replace('\\', '/') ?: "lib/main.dart"
            // Flutter may wrap an integration target in a generated listener.
            // The explicit define keeps native tests isolated in that case too.
            val integration = project.findProperty("dart-defines")?.toString()?.split(',')?.any {
                runCatching { String(Base64.getDecoder().decode(it)) == "DD_ANDROID_INTEGRATION=true" }.getOrDefault(false)
            } ?: false
            if (integration || entry.startsWith("integration_test/") || entry.contains("/integration_test/")) {
                applicationIdSuffix = ".integration"
            }
        }
    }
    packaging {
        jniLibs.excludes.addAll(listOf("lib/armeabi-v7a/**", "lib/x86/**"))
        jniLibs.useLegacyPackaging = true
        jniLibs.keepDebugSymbols.addAll(listOf("**/libpython.zip.so", "**/libffmpeg.zip.so"))
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("io.github.junkfood02.youtubedl-android:library:0.18.1")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.18.1")
}
