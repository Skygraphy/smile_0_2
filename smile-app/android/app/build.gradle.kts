import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    // Crash reports (monitoring stage 2, 2026-10-07)
    id("com.google.firebase.crashlytics")
}

// The test app (2026-10-19): built with --dart-define=SMILE_TEST=true it is
// "Smile Test" (com.smile.smile_app.test), installed next to the real app
// and talking to the testsuite project. Flutter hands the dart-defines to
// Gradle base64-encoded.
val smileTest = (project.findProperty("dart-defines") as String? ?: "")
    .split(",")
    .filter { it.isNotBlank() }
    .map { String(Base64.getDecoder().decode(it)) }
    .contains("SMILE_TEST=true")

// Google Play upload key (2026-11-16): only the app bundle for Play
// (`flutter build appbundle`) is signed with it. The APKs on our own
// devices stay on the debug key, so they can still be updated in place
// without uninstalling (which would unpair the kitchen Frame).
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val buildingBundle = gradle.startParameter.taskNames.any { it.contains("bundle", ignoreCase = true) }

android {
    namespace = "com.smile.smile_app"

    signingConfigs {
        if (keyProps.containsKey("storeFile")) {
            create("upload") {
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (foreground notifications) needs it.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.smile.smile_app"
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
        if (smileTest) applicationIdSuffix = ".test"
        manifestPlaceholders["appLabel"] = if (smileTest) "Smile Test" else "SmileApp"
        manifestPlaceholders["frameLabel"] = if (smileTest) "Frame Test" else "SmileFrame"
    }

    buildTypes {
        release {
            signingConfig =
                if (buildingBundle && keyProps.containsKey("storeFile")) signingConfigs.getByName("upload")
                else signingConfigs.getByName("debug")
            // Keeps what is only reached by reflection (WorkManager, proguard-rules.pro).
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Shrinking videos on the phone before upload (VideoCompressor.kt) --
    // same Media3 version video_player already brings in.
    implementation("androidx.media3:media3-transformer:1.9.2")
    implementation("androidx.media3:media3-effect:1.9.2")
    implementation("androidx.media3:media3-common:1.9.2")
    // Sending what waits in the upload queue with Smile closed (UploadWorker.kt).
    implementation("androidx.work:work-runtime-ktx:2.10.1")
}
